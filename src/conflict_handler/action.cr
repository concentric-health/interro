module Interro
  struct ConflictHandler(UpdateHandler)
    module Action
      abstract def to_sql(io, args : Array(Any)) : Nil
    end
  end
end
