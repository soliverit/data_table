require_relative "./print_helper.rb"
require_relative "./data_table.rb"
##
# DataTable with PrintHelper extensions
#
# DataTable is designed to work with tables. PrintHelper is designed
# to help prettyify console writing. This extension combines these
# so that you can pretty print DataTable content
##
class DataTable
	##
	# Print feature bounds
	##
	def printFeatureBounds
		puts LRPrintHelper.hashToTable(@featureBounds, padSize:12)
	end
	##
	#
	#
	# Print helper for listing features
	##
	def printFeatureSummary tabStart = true
		fullStr 	= ""
		str			= tabStart ? "\t" : ""
		record 		= @hashedData.first
		tempStrs	= []
		featureLen	= 0
		@features.each{|feature|
			featureLen = feature.to_s.length if feature.to_s.length  > featureLen
		}
		featureLen += 9
		@features.each_with_index{|feature, index|
			if (index + 3) % 3 == 0
				fullStr << tempStrs.join(" | ") + "\n" if tempStrs.length > 0
				tempStrs = []
			end
			tempStr = feature.to_s + ": " 
			tempStr = "\t" + tempStr if tabStart
			tempStr << (record[feature].class == String ? "CAT" : "Numeric")
			while tempStr.length < featureLen
				tempStr << " "
			end
			tempStrs.push tempStr
		}
		fullStr << tempStrs.join(" | ")
		puts fullStr	
	end
	##
	# Print the table to the console
	##
	def print
		tbl = Hash[@features.map{|feature| [feature, {}]}]
		@hashedData.each_with_index{|hData, idx| 
			@features.each{|feature|
				tbl[feature][idx.to_s.to_sym] = hData[feature]
			}
		}
		Lpr.hashToTable tbl
	end
end