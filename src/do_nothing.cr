require "./conflict_handler/action"

module Interro
  struct DoNothing
    include ConflictHandler::Action

    def to_sql(io, args : Array(Any)) : Nil
      io << "NOTHING"
    end
  end
end
