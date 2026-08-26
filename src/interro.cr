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

  # The fiber's currently open transaction, tracked per logical database.
  # `Interro.transaction` registers its transaction here so that a nested `Interro.transaction` call becomes a savepoint on the same connection instead of opening a second top-level transaction on a different pooled connection.
  @@ambient_transactions = {} of {Fiber, ::DB::Database} => Transaction

  def self.ambient_transaction(db : ::DB::Database) : Transaction?
    @@ambient_transactions[{Fiber.current, db}]?
  end

  def self.transaction(db : ::DB::Database = CONFIG.write_db, & : Transaction -> T) forall T
    if current = ambient_transaction(db)
      nested_transaction(current, db) { |txn| yield txn }
    else
      top_level_transaction(db) { |txn| yield txn }
    end
  end

  private def self.top_level_transaction(db : ::DB::Database, & : Transaction -> T) forall T
    result = uninitialized T
    db.using_connection do |connection|
      txn = connection.begin_transaction
      transaction = Transaction.new(txn)
      @@ambient_transactions[{Fiber.current, db}] = transaction

      begin
        result = yield transaction
        transaction.commit
        result
      rescue ex
        transaction.rollback
        raise ex
      ensure
        @@ambient_transactions.delete({Fiber.current, db})
      end
    end

    result
  end

  private def self.nested_transaction(current : Transaction, db : ::DB::Database, & : Transaction -> T) forall T
    savepoint = current.create_savepoint
    @@ambient_transactions[{Fiber.current, db}] = savepoint

    begin
      result = yield savepoint
      savepoint.commit
      result
    rescue ex
      savepoint.rollback
      raise ex
    ensure
      @@ambient_transactions[{Fiber.current, db}] = current
    end
  end
end
