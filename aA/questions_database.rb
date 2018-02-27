require "sqlite3"
require "singleton"


class QuestionsDatabase < SQLite3::Database
  include Singleton

  def initialize
    super('questions.db')
    self.type_translation = true
    self.results_as_hash = true
  end
end

class Question
  attr_accessor :title, :body, :author_id

  def self.most_liked(n)
    QuestionLikes.most_liked_questions(n)
  end

  def self.find_by_author_id(author_id)
    data = QuestionsDatabase.instance.execute(<<-SQL, author_id)
    SELECT
      *
    FROM
      questions
    WHERE
      author_id = ?
    SQL

    data.map {|datum| Question.new(datum)}
  end

  def self.find_by_question_id(question_id)
    data = QuestionsDatabase.instance.execute(<<-SQL, question_id)
    SELECT
      *
    FROM
      questions
    WHERE
      id = ?
    SQL

    Question.new(data.first)
  end

  def self.most_followed(n)
    QuestionsFollow.most_followed_questions(n)
  end

  def initialize(options)
    @id = options['id']
    @title = options['title']
    @body = options['body']
    @author_id = options['author_id']
  end

  def author
    raise "#{self} already in database" if @id
    QuestionsDatabase.instance.execute(<<-SQL, @title, @body, @author_id)
      INSERT INTO
        questions (title, body, author_id)
      VALUES
        (?, ?, ?)
    SQL
    @id = QuestionsDatabase.instance.last_insert_row_id
  end

  def replies
    reps = Reply.find_by_question_id(@id)
    raise "no replies" unless reps.length > 0
    reps
  end

  def followers
    QuestionsFollow.followers_for_question_id(@id)
  end

  def likers
    QuestionLikes.likers_for_question_id(@id)
  end

  def num_likes
    QuestionLikes.num_likes_for_question_id(@id)
  end
  def save
    raise "#{self} not in database" unless @id
    QuestionsDatabase.instance.execute(<<-SQL, @title, @body, @author_id, @id)
      UPDATE
        questions
      SET
        title = ?,
        body = ?,
        author_id = ?
      WHERE
        id = ?
    SQL

  end

end

class Reply
  attr_accessor :author_id, :question_id, :parent_reply, :body

  def self.find_by_user_id(author_id)
    data = QuestionsDatabase.instance.execute(<<-SQL, author_id)
    SELECT
      *
    FROM
      replies
    WHERE
      author_id = ?
    SQL

    data.map {|datum| Reply.new(datum)}
  end

  def self.find_by_reply_id(reply_id)
    data = QuestionsDatabase.instance.execute(<<-SQL, reply_id)
    SELECT
      *
    FROM
      replies
    WHERE
      id = ?
    SQL

    p data

    Reply.new(data.first)
  end

  def self.find_by_question_id(question_id)
    data = QuestionsDatabase.instance.execute(<<-SQL, question_id)
    SELECT
      *
    FROM
      replies
    WHERE
      question_id = ?
    SQL

    data.map {|datum| Reply.new(datum)}
  end

  def initialize(options)
    @id = options['id']
    @author_id = options['author_id']
    @question_id = options['question_id']
    @parent_reply = options['parent_reply']
    @body = options['body']
  end

  def author
    raise "#{self} already in database" if @id
    QuestionsDatabase.instance.execute(<<-SQL, @author_id, @question_id, @parent_reply, @body)
      INSERT INTO
        replies (author_id, question_id, parent_reply, body)
      VALUES
        (?, ?, ?, ?)

    SQL

    @id = QuestionsDatabase.instance.last_insert_row_id
  end

  def question
    Question.find_by_question_id(@question_id)
  end

  def parent_reply
    raise "no parent" unless @parent_reply
    Reply.find_by_reply_id(@parent_reply)
  end

  def child_replies
    data = QuestionsDatabase.instance.execute(<<-SQL, @id)
      SELECT
        *
      FROM
        replies
      WHERE
        parent_reply = ?

      SQL

      data.map { |datum| Reply.new(datum) }

  end

  def save
    raise "#{self} not in database" unless @id
    QuestionsDatabase.instance.execute(<<-SQL, @author_id, @question_id, @parent_reply, @body, @id)
      UPDATE
        users
      SET
        author_id = ?,
        question_id = ?,
        parent_reply = ?,
        body = ?
      WHERE
        id = ?
    SQL

  end
end

class User
  attr_accessor :fname, :lname

  def self.find_by_name (fname, lname)
    data = QuestionsDatabase.instance.execute(<<-SQL, fname, lname)
    SELECT
      *
    FROM
      users
    WHERE
      fname = ? AND lname = ?
    SQL

    data.map {|datum| User.new(datum)}
  end



  def initialize(options)
    @id = options['id']
    @fname = options['fname']
    @lname = options['lname']
  end

  def average_karma
    questions = self.authored_questions
    likes_per_question = []
    questions.each do |question|
      likes_per_question << (question.num_likes || 0)
    end
    likes_per_question.reduce(:+).fdiv(likes_per_question.length)
  end

  def authored_questions
    Question.find_by_author_id(@id)
  end

  def authored_replies
    Reply.find_by_user_id(@id)
  end

  def followed_questions
    QuestionsFollow.followed_questions_for_user_id(@id)
  end

  def liked_questions
    QuestionLikes.liked_questions_for_user_id(@id)
  end

  def save
    raise "#{self} not in database" unless @id
    QuestionsDatabase.instance.execute(<<-SQL, @fname, @lname, @id)
      UPDATE
        users
      SET
        fname = ?,
        lname = ?
      WHERE
        id = ?
    SQL

  end

end

class QuestionsFollow
  def self.followers_for_question_id(question_id)
    data = QuestionsDatabase.instance.execute(<<-SQL, question_id)
      SELECT
        *
      FROM
        users
      JOIN
        question_follows ON users.id = question_follows.user_id
      WHERE
        question_follows.question_id = ?
    SQL

    data.map { |datum| User.new(datum) }
  end

  def self.followed_questions_for_user_id(user_id)
    data = QuestionsDatabase.instance.execute(<<-SQL, user_id)
      SELECT DISTINCT
        *
      FROM
        questions
      JOIN
        question_follows ON questions.id = question_follows.question_id
      WHERE
        question_follows.user_id = ?
    SQL

    data.map { |datum| Question.new(datum) }
  end

  def self.most_followed_questions(n)
    data = QuestionsDatabase.instance.execute(<<-SQL, n)
      SELECT
        *
      FROM
        questions
      JOIN
        question_follows ON questions.id = question_follows.question_id
      GROUP BY
        questions.id
      ORDER BY
        COUNT(question_follows.user_id) DESC
      LIMIT
        ?
    SQL

    data.map { |datum| Question.new(datum)}
  end

end


class QuestionLikes
  def self.likers_for_question_id(question_id)
    data = QuestionsDatabase.instance.execute(<<-SQL, question_id)
      SELECT
        *
      FROM
        users
      JOIN
        question_likes ON users.id = question_likes.user_id
      WHERE
        question_id = ?
    SQL

    data.map { |datum| User.new(datum)}
  end

  def self.num_likes_for_question_id(question_id)
    data = QuestionsDatabase.instance.execute(<<-SQL, question_id)
      SELECT
        COUNT(*)
      FROM
        users
      JOIN
        question_likes ON users.id = question_likes.user_id
      WHERE
        question_id = ?
      GROUP BY
        question_id
    SQL
    return 0 if data.empty?
    data.first.values.first
  end

  def self.liked_questions_for_user_id(user_id)
    data = QuestionsDatabase.instance.execute(<<-SQL, user_id)
      SELECT
        *
      FROM
        questions
      JOIN
        question_likes ON questions.id = question_likes.question_id
      WHERE
        question_likes.user_id = ?
      SQL

      data.map { |datum| Question.new(datum) }
  end

  def self.most_liked_questions(n)
    data = QuestionsDatabase.instance.execute(<<-SQL, n)
      SELECT
        *
      FROM
        questions
      JOIN
        question_likes ON questions.id = question_likes.question_id
      GROUP BY
        questions.id
      ORDER BY
        COUNT(question_likes.user_id) DESC
      LIMIT
        ?
    SQL

    data.map { |datum| Question.new(datum)}
  end

end
