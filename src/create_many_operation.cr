require "db"
require "./conflict_handler"
require "./query_expression"
require "./types"

module Interro
  # :nodoc:
  struct CreateManyOperation(T)
    def initialize(@queryable : DB::Database | DB::Connection)
    end

    def call!(query : QueryBuilder(T), params : Array(NamedTuple), on_conflict conflict_handler : ConflictHandler? = nil) : Int32
      sql, args = generate_query query.sql_table_name, params,
        on_conflict: conflict_handler

      @queryable.exec(sql, args: args)
        .rows_affected
        # Postgres returns an Int64, but this will always be an Int32 because
        # Crystal arrays can only hold Int32::MAX elements.
        .to_i32
    end

    protected def generate_query(
      table_name : String,
      params : Array(NamedTuple),
      on_conflict conflict_handler : ConflictHandler?,
    ) : {String, Array(Any)}
      args = [] of Any
      sql = String.build do |str|
        str << "INSERT INTO " << table_name << " ("
        params.first.each_with_index(1) do |key, value, index|
          key.to_s.inspect str
          str << ", " if index < params.first.size
        end
        str << ") VALUES "
        params.each_with_index do |param, param_index|
          str << '('
          QueryExpression.build_values(param.values).to_sql str, args
          str << ')'
          if param_index < params.size - 1
            str << ','
          end
          str << ' '
        end
        if conflict_handler
          if (action = conflict_handler.action) && (handler_params = action.params)
            if handler_params.responds_to? :each_value
              # The VALUES lists consume one placeholder per row per column.
              start = params.size * params.first.size
              handler_params.each_value do |value|
                args << Interro::Any.new(value)
              end
            end
          end
          conflict_handler.to_sql str, start_at: start || 1
        end
      end

      {sql, args}
    end
  end
end
