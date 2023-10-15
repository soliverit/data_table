require "active_record"
require "./active_record_relation_extension.rb"
require "./data_table_with_print_helper.rb"

puts "
===========================================
To run this example:
	1) Create a database 
	2) Create a table called retrofits that has at least
	   three columns: 
		- operation_cost 	(numeric: annual running cost after retrofit)
		- area 				(numeric: affected area) 
		- ber 				(numeric: building energy rating in kgCO2/m2)

NOTE: This example includes the PrintHelper extension for printing
the DataTable to the console. To use DataTable without PrintHelper,
include './data_table.rb' instead of './data_table_with_print_helper.rb'
===========================================
"
# 1) Connect to database
ActiveRecord::Base.establish_connection(
  adapter:  'postgresql', 
  host:     'localhost',
  username: 'MY_USERNAME',
  password: 'MY_PASSWORD',
  database: 'MY_DATABASE_NAME',
  port:     5432
)
class Retrofit < ActiveRecord::Base

end
# Get the first 10 Retrofits
dataTable = Retrofit.select([:operation_cost, :area, :ber])
					.where("area > 100")
					.limit(10)
					.toDataTable
# Print table console
puts "Print full table"
dataTable.print
puts "Drop :operation_cost and print updated table"
dataTable.dropFeatures [:operation_cost]
dataTable.print