require "uri"
require "./spec_helper"
require "./config"

# A second, physically separate database to prove per-query-class routing via the `database` macro.
private SECOND_DB = begin
  uri = URI.parse(ENV.fetch("DATABASE_URL", "postgres:///"))
  base_name = uri.path.lchop('/')
  base_name = "interro" if base_name.empty?
  second_name = "#{base_name}_second"

  admin = DB.open(uri.to_s)
  begin
    unless admin.query_one?("SELECT 1 FROM pg_database WHERE datname = $1", second_name, as: Int32)
      admin.exec %(CREATE DATABASE "#{second_name}")
    end
  ensure
    admin.close
  end

  uri.path = "/#{second_name}"
  db = DB.open(uri.to_s)
  db.exec "DROP TABLE IF EXISTS widgets"
  db.exec <<-SQL
    CREATE TABLE widgets (
      id UUID PRIMARY KEY NOT NULL DEFAULT gen_random_uuid(),
      name TEXT NOT NULL
    )
  SQL
  db
end

private struct Widget
  include Interro::Model

  getter id : UUID
  getter name : String
end

private struct WidgetQuery < Interro::QueryBuilder(Widget)
  table "widgets"
  database SECOND_DB

  def create!(name : String) : Widget
    insert name: name
  end

  def with_name(name : String)
    where name: name
  end
end

describe "per-query-class databases" do
  it "routes reads and writes to the query's database" do
    widget = WidgetQuery.new.create!(name: "routed-#{UUID.random}")

    WidgetQuery.new.with_name(widget.name).to_a.map(&.id).should eq [widget.id]
    SECOND_DB.query_one("SELECT count(*) FROM widgets WHERE name = $1", widget.name, as: Int64).should eq 1
    # The default database never even received a widgets table, so nothing
    # could have leaked there.
    Interro::CONFIG.read_db
      .query_one?("SELECT 1 FROM pg_tables WHERE tablename = 'widgets'", as: Int32)
      .should be_nil
  end

  it "opens transactions on the query's database" do
    name = "rolled-back-#{UUID.random}"

    expect_raises(Exception, "boom") do
      Interro.transaction(SECOND_DB) do |txn|
        WidgetQuery[txn].create!(name: name)
        raise Exception.new("boom")
      end
    end

    WidgetQuery.new.with_name(name).to_a.should be_empty
  end
end
