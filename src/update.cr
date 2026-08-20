require "./conflict_handler/action"
require "./query_expression"

module Interro
  struct Update(T)
    include ConflictHandler::Action

    getter params : T

    def initialize(set @params)
    end

    def to_sql(io, args : Array(Any)) : Nil
      io << "UPDATE SET "
      {% if T <= Hash || T <= NamedTuple %}
        QueryExpression.build_set(params).to_sql io, args
      {% elsif T <= String %}
        io << params
      {% else %}
        {% raise "The `set` argument for `Interro::Update.new` must be a Hash, NamedTuple, or String. Got: #{T}" %}
      {% end %}
    end
  end
end
