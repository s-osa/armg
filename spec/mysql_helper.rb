# frozen_string_literal: true

class MysqlHelper
  MYSQL_HOST    = ENV.fetch('ARMG_TEST_MYSQL_HOST', '127.0.0.1')
  MYSQL_PORT    = ENV.fetch('ARMG_TEST_MYSQL_PORT', 10_056)
  MYSQL_USER    = ENV.fetch('ARMG_TEST_MYSQL_USER', 'root')
  MYSQL_DB      = ENV.fetch('ARMG_TEST_MYSQL_DB', 'armg_test')
  MYSQL_ENGINE  = ENV.fetch('ARMG_TEST_MYSQL_ENGINE', 'MyISAM')
  TABLE_OPTIONS = if ActiveRecord.gem_version < Gem::Version.new('6.1.0')
                    "ENGINE=#{MYSQL_ENGINE} DEFAULT CHARSET=utf8"
                  elsif MYSQL_ENGINE == 'InnoDB'
                    nil
                  else
                    "ENGINE=#{MYSQL_ENGINE}"
                  end

  def initialize
    @mysql = Mysql2::Client.new(
      host: MYSQL_HOST, port: MYSQL_PORT, username: MYSQL_USER
    )
  end

  def reset
    reset_db
    reset_ar
  end

  def dump
    buf = StringIO.new
    ActiveRecord::SchemaDumper.dump(ActiveRecord::Base.connection, buf)
    buf = buf.string.sub(/\A.*\bActiveRecord::Schema(?:\[[\d.]+\])?\.define\(version: \d+\) do/m, '').sub(/end\s*\z/, '')
    schema = buf.lines.map { |l| l.sub(/\A  /, '') }.join.strip

    # NOTE: Fix for ActiveRecord 6.1
    schema.gsub(', charset: "latin1"', '')
  end

  def create_table
    ActiveRecord::Migration.create_table :geoms, options: TABLE_OPTIONS do |t|
      t.geometry 'location', null: false
      t.index ['location'], name: 'idx_location', type: :spatial
    end

    ActiveRecord::Base.connection.execute("INSERT INTO geoms (id, location) VALUES (1, GeomFromText('POINT(1 1)', 1245))")
    ActiveRecord::Base.connection.execute("INSERT INTO geoms (id, location) VALUES (2, GeomFromText('LINESTRING(0 0,1 1,2 2)'))")
    ActiveRecord::Base.connection.execute("INSERT INTO geoms (id, location) VALUES (3, GeomFromText('POLYGON((0 0,10 0,10 10,0 10,0 0),(5 5,7 5,7 7,5 7, 5 5))', 5678))")
  end

  private

  def reset_db
    @mysql.query("DROP DATABASE IF EXISTS #{MYSQL_DB}")
    @mysql.query("CREATE DATABASE #{MYSQL_DB}")
    @mysql.query("USE #{MYSQL_DB}")
  end

  def reset_ar
    ActiveRecord::Base.establish_connection(
      adapter: 'mysql2',
      host: MYSQL_HOST,
      port: MYSQL_PORT,
      username: MYSQL_USER,
      database: MYSQL_DB
    )
  end
end

class Geom < ActiveRecord::Base
end
