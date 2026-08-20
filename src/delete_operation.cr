require "db"

require "./query_expression"
require "./error"

module Interro
  # :nodoc:
  struct DeleteOperation
    def initialize(@queryable : DB::Database | DB::Connection)
    end

    def call(table_name : String, where : QueryExpression)
      args = [] of Any
      sql = String.build do |str|
        str << "DELETE FROM " << table_name
        str << " WHERE "
        where.to_sql str, args
      end

      @queryable
        .exec(sql, args: args)
        .rows_affected
    end

    def call(table_name : String, where : Nil)
      raise UnscopedDeleteOperation.new("Invoked a DeleteOperation with no WHERE clause. If this is intentional, use a TruncateOperation instead")
    end

    class UnscopedDeleteOperation < Error
    end
  end
end
