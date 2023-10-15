##
# An extension to ActiveRecord::Relation that converts query results
# from Relations to DataTables.
#
# E.g, Car.where(brand: 'Audi').toDataTable returns DataTable
##
class ActiveRecord::Relation
	def toDataTable
		keys = if select_values.any?
			select_values
		else
			column_names
		end
		dataTable	= DataTable.new false, keys
		each{|record|
			dataTable.push Hash[keys.map{|columnName|[columnName, record.read_attribute(columnName)|| ""]}]
		}
		dataTable
	end
end