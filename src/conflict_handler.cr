require "./update"
require "./do_nothing"

module Interro
  struct ConflictHandler(UpdateHandler)
    getter action : Update(UpdateHandler) | DoNothing

    def initialize(@columns : String, do @action)
    end

    def to_sql(io, args : Array(Any)) : Nil
      io << "ON CONFLICT (" << @columns << ") DO "
      action.to_sql io, args
    end
  end
end
