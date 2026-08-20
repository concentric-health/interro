require "db"
require "./conflict_handler"
require "./query_expression"
require "./types"

module Interro
  # :nodoc:
  struct CreateOperation(T)
    def initialize(@queryable : DB::Database | DB::Connection)
    end

    def call(query : QueryBuilder(T), params, on_conflict conflict_handler : ConflictHandler? = nil) : T
      sql, args = generate_query query.sql_table_name, params,
        on_conflict: conflict_handler,
        returning: ->(io : IO) { query.select_columns io }

      @queryable.query_one sql, args: args, as: T
    end

    def call!(query : QueryBuilder(T), params, on_conflict conflict_handler : ConflictHandler? = nil) : Bool
      sql, args = generate_query query.sql_table_name, params,
        on_conflict: conflict_handler,
        returning: nil

      @queryable.exec(sql, args: args).rows_affected == 1
    end

    protected def generate_query(
      table_name : String,
      params,
      on_conflict conflict_handler : ConflictHandler?,
      returning returning_clause,
    ) : {String, Array(Any)}
      args = [] of Any
      sql = String.build do |str|
        str << "INSERT INTO " << table_name << " ("
        params.each_with_index(1) do |key, value, index|
          key.to_s.inspect str
          str << ", " if index < params.size
        end
        str << ") VALUES ("
        QueryExpression.build_values(params.values).to_sql str, args
        str << ") "
        if conflict_handler
          if (action = conflict_handler.action) && (handler_params = action.params)
            start = params.size
            handler_params.each_value do |value|
              args << Interro::Any.new(value)
            end
          end
          conflict_handler.to_sql str, start_at: start || 1
        end
        if returning_clause
          str << " RETURNING "
          returning_clause.call str
        end
      end

      {sql, args}
    end
  end
end
