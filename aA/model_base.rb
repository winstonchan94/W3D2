require "singleton"
require "sqlite3"
require_relative "questions_database"


class QuestionsDatabase < SQLite3::Database
  include Singleton

  def initialize
    super('questions.db')
    self.type_translation = true
    self.results_as_hash = true
  end
end

class ModelBase
  DATABASES = {
    Question => 'questions',
    User => 'users',
    Reply => 'replies'
  }


  def self.find_by_id(id)
    database = DATABASES[self]
    data = QuestionsDatabase.instance.execute(<<-SQL, id)
    SELECT
      *
    FROM
      #{database}
    WHERE
      id = ?
    SQL

    self.new(data.first)
  end

  def self.all
    database = DATABASES[self]
    data = QuestionsDatabase.instance.execute(<<-SQL)
    SELECT
      *
    FROM
      #{database}
    SQL
    
    data.map {|datum| self.new(datum)}
  end

end
