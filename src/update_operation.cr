require "db"

require "./query_expression"

module Interro
  # :nodoc:
  struct UpdateOperation(T)
    def initialize(@queryable : DB::Database | DB::Connection)
    end

    def call(query, set values : NamedTuple, where : QueryExpression? = nil)
      sql, sql_args = render(query, set: QueryExpression.build_set(values), where: where, returning: true)

      @queryable.query_all sql, args: sql_args, as: T
    end

    def call(query, set values : String, args : Array(Value) = [] of Value, where : QueryExpression? = nil)
      sql, sql_args = render(query, set: QueryExpression.parse(values, args), where: where, returning: true)

      @queryable.query_all sql, args: sql_args, as: T
    end

    def call!(query, set values : NamedTuple, where : QueryExpression? = nil) : Int64
      sql, sql_args = render(query, set: QueryExpression.build_set(values), where: where, returning: false)

      @queryable.exec(sql, args: sql_args).rows_affected
    end

    def call!(query, set values : String, args : Array(Value) = [] of Value, where : QueryExpression? = nil) : Int64
      sql, sql_args = render(query, set: QueryExpression.parse(values, args), where: where, returning: false)

      @queryable.exec(sql, args: sql_args).rows_affected
    end

    private def render(query, set values : QueryExpression, where : QueryExpression?, *, returning : Bool) : {String, Array(Any)}
      table_name = query.sql_table_name
      sql_args = [] of Any
      sql = String.build do |str|
        str << "UPDATE " << table_name << ' '
        str << "SET "
        values.to_sql str, sql_args

        if where
          str << " WHERE "
          where.to_sql str, sql_args
        end

        if returning
          str << " RETURNING "
          query.select_columns str
        end
      end

      {sql, sql_args}
    end
  end
end
