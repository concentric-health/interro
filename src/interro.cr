require "benchmark"
require "db"
require "pg"

require "./types"
require "./query"
require "./config"
require "./query_builder"
require "./model"
require "./transaction"
require "./ext/db/serializable"
require "./ext/pg/result_set"

#
module Interro
  VERSION = "0.6.3"

  def self.transaction(db : ::DB::Database = CONFIG.write_db, & : Transaction -> T) forall T
    result = uninitialized T
    db.using_connection do |connection|
      txn = connection.begin_transaction
      transaction = Transaction.new(txn)

      begin
        result = yield transaction
        transaction.commit
        result
      rescue ex
        transaction.rollback
        raise ex
      end
    end

    result
  end
end
