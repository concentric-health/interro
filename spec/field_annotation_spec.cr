require "./spec_helper"
require "./config"

# Column selection (QueryBuilder#select_columns) treats Interro::Field and DB::Field as interchangeable, so row deserialization must honor both too — whichever serialization module the model includes.
# Otherwise a key:/ignore: annotation is applied when building the SELECT but not when reading the row, and deserialization fails at runtime.

private struct AnnotatedUser
  include Interro::Model

  getter id : UUID

  @[DB::Field(key: "email")]
  getter email_address : String

  getter name : String

  @[DB::Field(ignore: true)]
  property memo : String?
end

private struct AnnotatedUserQuery < Interro::QueryBuilder(AnnotatedUser)
  table "users"

  def create!(email : String, name : String) : AnnotatedUser
    insert email: email, name: name
  end

  def with_name(name : String)
    where name: name
  end
end

private struct MirrorUser
  include DB::Serializable

  getter id : UUID

  @[Interro::Field(key: "email")]
  getter email_address : String

  getter name : String

  @[Interro::Field(ignore: true)]
  property memo : String?
end

private struct MirrorUserQuery < Interro::QueryBuilder(MirrorUser)
  table "users"

  def create!(email : String, name : String) : MirrorUser
    insert email: email, name: name
  end

  def with_name(name : String)
    where name: name
  end
end

describe "field annotations" do
  it "honors DB::Field annotations when deserializing an Interro::Model" do
    name = "Annotated #{UUID.random}"
    user = AnnotatedUserQuery.new.create!(email: "annotated-#{UUID.random}@example.com", name: name)

    fetched = AnnotatedUserQuery.new.with_name(name).first
    fetched.email_address.should eq user.email_address
    fetched.memo.should be_nil
  end

  it "honors Interro::Field annotations when deserializing a DB::Serializable" do
    name = "Mirror #{UUID.random}"
    user = MirrorUserQuery.new.create!(email: "mirror-#{UUID.random}@example.com", name: name)

    fetched = MirrorUserQuery.new.with_name(name).first
    fetched.email_address.should eq user.email_address
    fetched.memo.should be_nil
  end
end
