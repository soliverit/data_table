############ Includes #############
###
# Native includes
##
if RUBY_VERSION.to_s[0] == "3"
	require "active_support/all"
else
	require "active_support"
end
require "csv"

###
# Library includes
##
require_relative "./print_helper.rb"
#####################################################
# Regression Data Set								#
#													#
# Standardised interactions with data and general	#
# abstraction of the general things you might want	#
# to do with a data set. 							#
#													#
# Essentially, this split data into both an Array	#
# and a Hash and applies cloning for normalisation,	#
# splitting, partitioning, external requests for	#
# the data not using @data or @hashedData directly.	#
#													#
# Apart from that, it parses CSV files!				#
#####################################################
class DataTable
	attr_reader :data, :hashedData, :features, :scale, :asInteger
	attr_accessor :greedyBounds, :normalise
	ID_COLUMN_NAME			= :id
	NUMBER_REGEX 			= /^-?\d+\.?\d*([Ee][-\+]\d+)?$/
	BLANK_CELL_REGEX		= /^\s*$/
	LINE_TERMINATOR_REGEX	= /\r?\n$/
	##
	# Parse Through CSV-gem
	##
	def self.parseCSV path
		csv = CSV.read(path,encoding: 'r:bom|utf-8')
		output = self.new false, csv[0].map{|column| column.to_sym}
		i = 0
		while (i += 1) < csv.length
			csv[i].map!{|value|
				
				if value 
					# Skip blank lines (excel's bein' a dick wi some CSVs)0
					next if value.match(/^s*$/)
					if value.match(/^-?\d+(\.\d+)?$/)
						value.match(/\./) ? value.to_f : value.to_i
					else
						value.to_s
					end
				end
			}
			
			output.push csv[i]
		end
		output
	end
	def toCSV path
		CSV.open(path, "w"){|csv|
			csv << features
			@data.each{|data| csv << data}
		}
	end
	##
	# data:		Base data set, either nil, Array[] or Array[Hash]
	# features:	Feature labels for data. Array[Symbol]
	#
	# Notes:
	#	- IF data is nil, features must be an Array of symbols
	#	- IF data is Hash, features should be nil
	# 	- IF data is Array, features should be Array of symbols
	#
	#	- Features set must be the same length of the entries in each record
	#
	# @features:		Features set
	# @data:			Data represented as an Array[Array]
	# @hashedData:		Data represented as an Array[Hash]
	# @featureBounds:	Hash of feature min-max values
	# @greedyBounds:	Flag to determine if .push updates @featureBounds? Boolean
	# @normalise:		Normalise data when requested through getDataStructure? Boolean
	# @scale:			Scaling factor for numeric values
	# @asIteger:		Should numeric values be returned as integers from getDataStructure
	# @catKeys:			Hash of array for feature category labels
	##
	def initialize input, features, scale=1, asInteger=false
		@greedyBounds 	= true
		@normalise		= false
		@scale			= scale
		@asInteger		= asInteger
		@catKeys		= {}
		@data 			= []
		@hashedData		= []
		@indices		= {}
		@features 		= features ? features.dup : []
		input			= input.dup if input
		if input
			if  input.first.class == Hash
				@features 	= input.first.keys.dup
			end
			getFeatureBounds
			input.map{|entry| push entry}
		end
		#Skip if it's been done already due to Hash or Array construction
		getFeatureBounds if ! @featureBounds
	end
	##
	# Add unique index or greedy unique 
	##
	def addIndex feature, warning = false
		feature = feature.to_sym
		@indices[feature] = {}
		@hashedData.each{|data|
			@indices[feature][data[feature]] = data
		}
	end
	def hasIndex? feature
		return @indices.key? feature.to_sym
	end
	##
	# Is the passed feature present in the set?
	#
	# feature:	Feature name, hopefully a symbol but no point forcing it
	#
	# Output:	Boolean, feature is present?
	##
	def hasFeature? feature
		@features.include? feature
	end
	##
	# Partition the data set into a new set of RegressionDataSets
	# of the length of the input
	#
	# count:	Number of RegressionDataSets to split data into
	#
	# Output:	Array of RegressionDataSets, hopefully same cardinality
	##
	def partition count
		outputs 	= (1..count).map{|i|
			output = self.class.new nil, features
			output.normalise = @normalise
			output
		}
		i			= 0
		@data.each{|data|
			i = 0 if i == outputs.length
			outputs[i].push data.dup
			i += 1
		}
		outputs		
	end
	##
	# Segregate data by feature name. Essentially vertical equivalent of split
	#
	# splitFeatures:	Feature labels to be given to a new class instance
	# divide:			Should the features removed from this object as well?
	#
	# Output:			New instance of the class with columns from input
	##
	def segregate splitFeatures, divide = false
		output = RegressionDataSet.new nil, splitFeatures
		output.normalise = @normalise
		@hashedData.each{|data| output.push Hash[splitFeatures.map{|feature| [feature, data[feature]]}]}
		dropFeatures splitFeatures if divide
		output
	end
	##
	# Merge the data in the pass set as deep clone
	#
	# dataSet:	RegressionDataSet to be merged with this set
	##
	def << dataSet
		raise "RegressionDataSet:FeatureMisMatchException. Inconsistent keys between this and passed set" if @features.map{|f|
		true if dataSet.hasFeature? f
		}.compact.length != @features.length
		dataSet.hashedData.each{|data|
			push Hash[@features.map{|feature|
				[feature, data[feature]]
			}]
		}
	end
	##
	# Generate an Array of data sets, grouped by the passed key
	#
	# key:		Feature name Symbol identifying the group by property
	#
	# Output:	An Array of RegressionDataSets with same length as
	#			the distinct number of values the column
	##
	def	groupBy key
		output = {}
		@hashedData.each{|data|
			newKey = data[key].to_s.to_sym
			if ! output[newKey]
				output[newKey] = self.class.new nil, features
			end
			output[newKey].push data
		}	
		output
	end
	##
	# Group by function
	#
	# &block:	Proc which accepts a value and churns out the group alias
	#
	# Output:	Hash of RegressionDataSets with keys named after function outputs
	##
	def groupByFunction &block
		outputs = {}
		@hashedData.each{|data|
			newKey = yield(data).to_s.to_sym
			if ! outputs[newKey]
				outputs[newKey] = self.class.new nil, features
			end
			outputs[newKey].push data
		}
		outputs
	end
	##
	# Split this data set into two RegressionDataSets
	#
	# percent:	Split percentage for first set
	#
	# Output:	Array of two RegressionDataSets containing
	#			the data from this set
	##
	def split percent
	
		splitSize 			= (@data.length * percent).to_i
		firstSet			= RegressionDataSet.new nil, features, @scale, @asInteger
		secondSet			= RegressionDataSet.new nil, features, @scale, @asInteger
		firstSet.normalise 	= @normalise
		secondSet.normalise	= @normalise
		i = 0
		while i < @data.length
			if i < splitSize
				firstSet.push @data[i].dup
			else
				secondSet.push @data[i].dup
			end
			i += 1
		end
		[firstSet, secondSet]
	end
	##
	# Push a new feature to the features
	#
	# Add new feature and safely / quickly set min-max bound
	##
	def pushFeature newFeature
		if ! @features.include? newFeature
			@featureBounds[newFeature] = {min: 9999999999999999, max: -999999999999999999999}
			@features.push newFeature
		end
	end
	##
	# Inject a collection of features, filling with a single value for each
	#
	# inFeatures:	A Hash of the feature keys and values to be injected
	##
	def injectFeatures inFeatures
		featureIndices = {}
		inFeatures.keys.each{|feature|
			@features.push feature if ! @features.include? feature
			featureIndices[feature] = @features.find_index feature
		}
		@hashedData.each_with_index{|hData, index|
			inFeatures.keys.each{|fKey|
				hData[fKey] 						= inFeatures[fKey]
				data[index][featureIndices[fKey]] 	= inFeatures[fKey]
			}
		}
		nil
	end
	##
	# Inject feature by function. 
	#
	# Use a function to pry a value from each record and inject it into
	# said record.
	#
	# feature:	Symbol of new or to be modified feature name
	# &block:	Proc(@hashedData<record>, featureName) to return value
	#
	# Example:	Proc.new{|record, feature| record[feature] + 10}
	#
	# Notes:
	#	- Don't worry, since I can't be trusted the is Hash-safe using dup 
	#	  to prevent replacement of values
	#	- Obviously using Proc.new is un-Ruby, just rattle (){|r,f|...} after the call
	#
	# TODO: Consider if .dup is really necessary. It's probably fine but a bit 
	# 		of a bugger for performance if the set of features is massive since it
	#		increases from what is probably O(n) to O(n*f)
	##
	def injectFeatureByFunction feature, &block
		pushFeature feature if ! @features.include? feature
		featureIndex = @features.find_index feature
		@hashedData.each_with_index{|hData, index|
			value = yield(hData.dup, feature)
			hData[feature] 						= value
			data[index][featureIndex] 			= value
		}
		nil
	end
	##
	# Inject columns for the domain boundaries of the desired feature
	#
	# Notes:
	#	- This is ideally only meant for homogeneous data sets such as 
	#	  single building feature sets. Go nuts if you want though, just
	#	  don't email me bitchin' about how you treated the feature like
	#	  /r/programmerHumor treats Javascript...
	##
	def injectTargetFeature feature
		raise "RegressionDataSet::InvalidFeatureException" if ! @features.include? feature
		### Add boundary keys and track the target
		@features.push :domainLowerBound if ! @features.include? :domainLowerBound
		@features.push :domainUpperBound if ! @features.include? :domainUpperBound
		@domainTarget = feature
		
		### Inject the min/max to the Array and Hash data sets
		domainLowerFeatureID = @features.find_index :domainLowerBound
		domainUpperFeatureID = @features.find_index :domainUpperBound
		@data.each_with_index{|data, index|
			data[domainLowerFeatureID] 	= @featureBounds[@domainTarget][:min]
			data[domainUpperFeatureID] 	= @featureBounds[@domainTarget][:max]
			@hashedData[index][:domainLowerBound] 		= @featureBounds[@domainTarget][:min]
			@hashedData[index][:domainUpperBound] 		= @featureBounds[@domainTarget][:max]
		}
		### Don't return anything in case someone abuses the mutable stuff! ###
		nil
	end
	##
	# Get current domain feature label
	#
	# Output:	
	##
	##
	# Retrieve and remove target
	##
	def retrieveFeatureAsArray feature, remove = false
		output = getSingleFieldArray feature
		dropFeatures [feature] if remove
		output
	end
	##
	# Retrieve single feature Hash and possibly remove feature
	##
	def retrieveFeatureAsHash feature, remove = false
		output = getSingleFieldHash feature
		dropFeatures [feature] if remove
		output
	end
	##
	# Number of records in the data set
	#
	# Output:	Data set length. Integer
	##
	def length
		@hashedData.length
	end
	##
	# Return this data set's features list in safe array
	#
	# Output:	Array of features. Array[Symbol]
	##
	def features
		@features.map{|feature| feature}
	end
	##
	# Random sort the data
	##
	def randomSort
		@data = []
		@hashedData.sort{Random.rand <=> Random.rand}
		@hashedData.each{|data|	@data.push @features.map{|feature| data[feature] }}
	end
	##
	# Generate a sample set of this mode.
	#
	# Output:	Returns a random sample of the set. RegressionDataSet
	##
	def sample limit = nil
		limit = @data.length - 1 if limit == nil
		limit = @data.length - 1 if limit > @data.length
		limit = (@data.length * limit).to_i if limit <= 1
		newDataSet = RegressionDataSet.new nil, features
		@hashedData.sort{|a, b| Random.rand <=> Random.rand}[0, limit].each{|data|
			newDataSet.push Hash[@features.map{|feature| [feature,data[feature]]}]
		}
		newDataSet
	end
	##
	# CLone self and return a new RegressionDataSet
	#
	# Output:	New RegressionDataSet identical to this but
	# 			with safe array data
	##
	def clone
		newDataSet = self.class.new nil, features, @scale, @asInteger
		newDataSet.normalise = @normalise
		@hashedData.each{|data| 
			newData = {}
			@features.each{|feature| newData[feature] = data[feature]}
			newDataSet.push newData
		}
		newDataSet
	end
	##
	# Count the distinct values in a column
	#
	# target:	Symbol of the target feature
	#
	# Output:	RegressionDataSet with unique values as header
	#			and values as counts
	##
	def countKey target
		outputData = {}
		@hashedData.each{|val|
			newKey = val[target].to_s.to_sym
			outputData[newKey] = 0 if ! outputData[newKey]
			outputData[newKey] += 1
		}
		temp = self.class.new [outputData], nil
	end
	##
	# Distnct values from column
	#
	# SERIOUSLY!!! Who calls distinct countKey.
	#
	# Output: As countKey (rgDataSet unique values from target)
	##
	def distinct target
		output 	= self.class.new false, [target.to_sym]
		temp 	= [] 
		@hashedData.each{|data| 
			if ! temp.include? data[target]
				temp.push data[target]
				output.push [data[target]]
			end
		}
		output
	end
	##
	# Join with assumption of strict sorting in both rgDataSets
	##
	def join rgDataSet
		rgDataSet.features.map{|feature| @features.push(feature) if ! @features.include?(feature)}
		rgDataSet.data.each_with_index{|data, index|
			rgDataSet.features.each_with_index{|feature, fIndex|
				@data[index][@features.find_index feature] = data[fIndex]
				@hashedData[index][feature] = data[fIndex]
			}
		}
		getFeatureBounds
	end
	def joinBy rgDataSet, feature
		output	= self.class.new false, [rgDataSet.features, features].flatten.uniq
		joinIndex = Hash[rgDataSet.hashedData.map{|data| [data[feature].to_s, data]}]
		#rgDataSet.features.map{|feature| @features.push(feature) if ! hasFeature? feature}
		@hashedData.each{|data| 
			keyValue = data[feature].to_s
			newData = Hash[output.features.map{|feature| [feature, data[feature] || 0]}]
			if joinIndex[keyValue]
				joinIndex[keyValue].each{|key, value| newData[key] = value}
			end
			output.push newData
		}
		output
	end
	def findBy key, value
		return false if ! @indices[key]
		@indices[key][value]
	end
	def find 
		@hashedData.each{|data|
			return data.dup if yield data
		}
		false
	end
	##
	# Return a single dimension array of a keyed value
	#
	# key:	Key of feature to extract
	#
	# Output:	Single dimension array based on input key
	##
	def getSingleFieldArray key
		@hashedData.map{|data| data[key]}
	end
	##
	# Get single feature Hash Array
	##
	def getSingleFieldHash key
		@hashedData.map{|data| {key: data[key]}}
	end
	##
	# Apply a Proc to the data
	#
	# Notes:
	#	- This will update all the values in the data based
	#	  on the passed Proc. It is not suitable for 
	#	  nil return Procs
	##
	def apply &block
		@hashedData.each_with_index{|entry, idx|
			yield(entry) 
			@data[idx] = @features.map{|feature| entry[feature]}
		}
	end
	##
	##
	# Generate Min/Max data for each feature
	#
	# Notes:
	#	- Iterates over every record and creates a Hash entry for each
	#	  feature {feature_name: {min:<val>, max:<val>},..}
	##
	def getFeatureBounds
		@featureBounds = Hash[@features.map{|feature| [feature, {min:99999999, max:0}]}]
		if length > 0
			@features.each{|feature| 
				next if @hashedData.first[feature].class == String
				@hashedData.each{|hData|
					@featureBounds[feature][:min] = hData[feature] if hData[feature] < @featureBounds[feature][:min]
					@featureBounds[feature][:max] = hData[feature] if hData[feature] > @featureBounds[feature][:max]
				}
			}
		end
	end
	##
	# Remove features from data set
	#
	# Notes: 
	#	- Remove a set of features from the data set, 
	#	  @data, @hashedData and @features.
	##
	def dropFeatures features
		features.each{|feature|
			@featureBounds.delete feature
			featureIndex = nil
			@features = @features.each_with_index.map{|f, index| 
				if feature == f
					featureIndex = index 
					nil
				else
					f
				end
			}.compact
			newData = []
			@data.map!{|entry|
				record = []
				entry.each_with_index{|val, idx| record.push val if idx != featureIndex}
				record
			}
			@hashedData.each{|data|
				data.delete feature
			}
		}
	end
	##
	# Return data in prefered format
	#
	# hash:		Should data be returned as Hash or Array? Boolean
	#
	# Output:	Either the data set as a Hash or Array, as requested
	##
	def getDataStructure useHash
		if useHash
			@normalise ? normalisedHash : @hashedData
		else
			@normalise ? normalisedData : @data
		end
	end
	##
	# Normalise value
	#
	# PROBABLY DOESN'T WORK: Need to know what from and to are about
	#
	# TODO: Transfer to Class method, perhaps on the Base class?????????
	##
	def self.normalise val, key
		# (val - @featureBounds[key][:min]) * (toHigh - toLow) / (fromHigh - fromLow).to_f
		(val - @featureBounds[key][:min]) * (@featureBounds[key][:max] - @featureBounds[key][:min]) / (@featureBounds[key][:max] - @featureBounds[key][:min]).to_f
	end
	##
	# Get a normalised version of @hashedData
	#
	# Output:	Hash identical to @hashedData but normalised
	#
	# Notes:
	#	- Wonder if this is an actual normalisation method, look into it
	#	- Wouldn't use this just now!!!!!
	##
	def normalisedHash
		return @normalisedHash if @normalisedHash
		output = []
		# i = 0
		@hashedData.each{|entry|
			normalisedEntry = {}
			@features.each{|feature|
				if @hashedData.first[feature].class != String
					normalisedEntry[feature] = self.class.normaliseValue entry[feature], @featureBounds[feature][:min], @featureBounds[feature][:max]
				else
					normalisedEntry[feature] = entry[feature]
				end
			}
			output.push normalisedEntry
		}
		@normalisedHash = output
	end
	##
	# Generate feature boundaries summary from set
	#
	# rgDataSet:	RegressionDataSet
	#
	# Output:		Hash of {feature_name:{min:value, max: value},...}
	##
	def self.hashFeatureBounds rgDataSet
		output = Hash[rgDataSet.features.map{|feature| [feature, {min:99999999, max:0, avg:0}]}]
		hashedData = rgDataSet.getDataStructure(true)
		if rgDataSet.length > 0
			rgDataSet.features.each{|feature| 
				next if hashedData.first[feature].class == String
				hashedData.each{|hData|
					output[feature][:min] = hData[feature] if hData[feature] < output[feature][:min]
					output[feature][:max] = hData[feature] if hData[feature] > output[feature][:max]
					output[feature][:avg] += hData[feature]
				}
			}
		end
		rgDataSet.features.each{|feature| output[feature][:avg] /= rgDataSet.length}
		output
	end
	##
	# Get a normalised version of @data
	#
	# Output:	Normalised Array[Array[N-Features]] from @data
	#
	# Notes:
	#	- See normalisedHash notes
	##
	def normalisedData
		@normalisedData ||= @data.map{|data|
			@features.each_with_index.map{|feature, index|
				if data[index].class == String
					data[index] = data[index]
				else
					data[index] = self.class.normaliseValue data[index], @featureBounds[feature][:min], @featureBounds[feature][:max]
				end
			}
		}
	end
	##
	# Push an entry to the data set
	#
	# input:	Either an Array or Hash for a single entry
	# 
	# Notes:
	#	- IF input == Hash, All the keys in @features must existing
	#	- IF input == Array, The length of the Array must be equalto @features.length
	##
	def push input
		if input.class== Hash
			hData = {}
			@data.push @features.map{|feature| 
				hData[feature] = input[feature]
				input[feature]
			}
			@hashedData.push hData
		else
			##
			# Treat all pushes like an array of value rows and
			# make send individuals on their own
			##
			if input.first.class == Array
				input.each{|inp|
					self.push inp
				}
				return
			end
			@hashedData.push Hash[(0...@features.length).map{|index| [@features[index], input[index]]}]
			@data.push input.dup
		end
		begin
		lastEntry = @hashedData.last
		a= false
		if @greedyBounds			
			@features.each{|feature|
				next if lastEntry[feature].class == String
				@featureBounds[feature][:min] = lastEntry[feature] if lastEntry[feature] < @featureBounds[feature][:min]
				@featureBounds[feature][:max] = lastEntry[feature] if lastEntry[feature] > @featureBounds[feature][:max]
			}
		end
		unless @indices.empty?
			@indices.keys.each{|key|
				@indices[key][lastEntry[key]] = lastEntry
			}
		end
		rescue Exception => e
			# puts lastEntry.to_yaml
			# puts e.message
		end
		@normalisedHash = false
		@normalisedData = false
	end
	
	##
	# Filter keys by regex. 
	#
	# pattern:	A regular expression for matching feature labels
	#
	# Output:	An Array of feature labels matching the input pattern
	##
	def filterFeatures pattern
		@features.map{|feature| feature if feature.to_s.match(pattern)}.compact
	end
	##
	# Filter data by function
	##
	def filterByFunction 
		output = self.class.new false, features
		@hashedData.each{|data| 
			output.push data unless yield data
		}
		output
	end
	##
	# Select records from set return new RDS (take a block)
	##
	def select
		output = self.class.new false, features
		@hashedData.each{|data| 
			output.push data.dup if yield data
		}
		output
	end
	##
	# Sort in place WARNGING: Clearly not finished. Fuck sake, man!
	## 
	def sort! &block
		sortedData 	= @hashedData.sort &block
		@data 		= []
		@hashedData	= []
		sortedData.each{|data| push data}
	end
	

	
	##
	# Find incomplete records
	#
	# Return:		DataTable containing all records that are missing records
	##
	def findIncompleteRecords
		output = self.class.new false, @features.dup
		@data.each{|data|
			if data.find_index nil
				output.push data
			end
		}
		output
	end
	##
	# Do something with each data entry hash
	##
	def each &block
		@hashedData.each{|data, idx| yield data, idx}
	end
	def map &block
		@hashedData.map!{|data, idx| yield data, idx}
	end
	##
	# Catify column
	#
	# Convert unique values into labels 
	##
	def catify feature
		@catKeys[feature] 	= []
		distinct(feature).each{|dFeature, idx| 
			@catKeys[feature].push dFeature[:weather]
			injectFeatureByFunction(dFeature[:weather].to_sym){|data| 
				data[feature] == dFeature[:weather] ? 1 : 0
				@featureBounds[feature][:min] = 0
				@featureBounds[feature][:max] = 0
			}
		}
		

	end
	##
	# Swap existing features with new names.
	#
	# For example: :GridSupElec to :grid_supplied_electricity
	##
	def swapFeatures pairs
		@features	= @features.map{|feature|
			pairs[feature] ? pairs[feature] : feature
		}
		@hashedData.each{|data|
			pairs.each{|existing, replacement|
				## Update hashed records
				data[replacement]	= data[existing]
				data.delete existing
				## Update feature boundaries
				@featureBounds[replacement]	= @featureBounds[existing]
				@featureBounds.delete existing
			}
		}

	end
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
