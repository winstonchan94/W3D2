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

  def save
    vars = self.instance_variables.map(&:to_s)
    set_string = ""
    vars.each do |var|
      next if var == '@id'
        set_string += var[1..-1] + " = ?,\n"
    end
    set_string = set_string[0..-3]

    vars_string = self.instance_variables.join(', ').to_s
    raise "#{self} not in database" unless @id
    QuestionsDatabase.instance.execute(<<-SQL, vars_string)
      UPDATE
        #{DATABASES[self]}
      SET
        #{set_string}
      WHERE
        id = ?
    SQL

  end

  def self.where(options)
    arguments = options.sort
    num_arg = arguments.length
    arguments.flatten!
    arguments.map!(&:to_s)
    vars_string = arguments.join(', ').to_s
    where_array = []
    num_arg.times { where_array << '? = ?'}
    where_string = where_array.join('AND ')
    p where_string
    p vars_string
    # heredoc = <<-SQL, *arguments
    #   SELECT
    #     *
    #   FROM
    #     #{DATABASES[self]}
    #   WHERE
    #     #{where_string}
    #   SQL
    #   p heredoc



    data = QuestionsDatabase.instance.execute(<<-SQL, *arguments)
      SELECT
        *
      FROM
        #{DATABASES[self]}
      WHERE
        #{where_string}


      SQL
    p data
    data.map {|datum| self.new(datum)}
  end

end
