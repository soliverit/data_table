# DataTable with ActiveRecord::Relation extension
An over-the-top inline Sql-type data handling model with an extension to ActiveRecord::Relation enabling conversion from query results to DataTable objects.

### ActiveRecord example
See "./example.rb" for full example
```ruby
class Retrofit < ActiveRecord::Base
    # Table has at least three columns: :operation_cost, :area, :ber
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
```
Output:
<br/>
<img src="https://i.imgur.com/HOW6GlB.png" width="300" height="425" />


### DataTable usage
```ruby
##
# Create two new data sets for the examples, split one into two.
#
# Example: User and Phone data (name, id) and phone (type, user_id)
##
# New takes two params, data and features. One should always be false
userData  = DataTable.new false,[:name, :id]
phoneData = DataTable.new false, [:type, :user_id]
#Add some data. The Push method accepts an Array or Hash
userData.push ["Dave", 1]
userData.push({name: "Tam", id: 5})
userData.push ["Shug", 3]
userData.push ["Harold", 2]
userData.push ["Dug", 4]

phoneData.push ["Nokia", 2]
phoneData.push({type: "Samsung", user_id: 1})
phoneData.push ["Apple", 3]
phoneData.push["Nokia", 4]
phoneData.push ["Samsung" 5]
#####################
# Functions         #
#####################
### Properties ###
userData.features #List of features
userData.length #Number of records
### Querying, joining and splitting ###
##
# Filter data by function. Retrun new RegressionDataSet
##
filteredUserData  = userData.filterByFunction{|data| data[:id] > 2}
##
# Select data by function. Return new RegressionDataSet
##
selectedUserData = userData.select{|data| data[:name].match(/^Dav(e|id)$/)
##
# Splitting (Returns [RegressionDataSet, RegressionDataSet]
#
#Takes one param, split ratio / No. records. < 1 = ratio, > 1 = No.
##
splitUserData = userData.split 0.5
##
# Partitioning. Returns an N-sized Array of RegressionDataSets
# Takes one param, Number of output RegressionDataSets
##
splitPhoneData = userData.partition 3
##
# Retrieve a sample of records from the data based on the 0 < input < 1 passed parameter
##
sampleUserData = userData.sample 0.3
##
# Segregating (Vertical split by feature aliases)
#
# Split data into two data sets veritcally. Pass feature list for the output.
#
# Param 1:  An Array of features names which are in teh dataset
# Param 2:  Boolean, should these output features be dropped from the base dataset?
##
userDataFeatureSplit = userData.segregate [:name], true
##
# Merge two RegressionDataSets
##
mergedData = splitUserData.first << splitUserData.last
##
# Join two RegressionDataSets with differing features
#
# NOTE: This method assumes a 1:1 relationship between the first and second sets' row ID
joinedData = userData.join phoneData
##
# Group by feature Retruns Array of RegressionDataSets where length == dataset.<feature> unique values length
##
groupedUserData = userData.groupBy :name
##
# Group by function (Returns Array of RegressionDataSets where length == dataset.<feature> unique values length
##
groupedUserData = userData.groupByFunction{|data| data[:name] != "Dave"}
##
# Apply a function to the data
##
userData.apply{|data| data[:name] = data[:name].titlecase}
### Sorting ###
##
# Sort the data (Inline). Takes function (Proc) as any other <=> sort operator use
##
userData.sort!{|a, b| a[:id] <=> b[:id]} 
### Adding new features to the data ###
## 
# Inject features with default values from a Hash
##
userData.injectFeatures({age:20})
##
# Inject a feature and set values by function
##
userData.injectFeatureByFunction(:type){|data| data[:age] < 18 ? "dependent" : "adult"}
### Getting the data from the dataset
##
# Retrieve a Hash for the requested feature
#
# Param 1: Symbol / String. Which feature
# Param 2:  Boolean (Optional), should the feature be removed from the dataset?
##
nameHash = userData.retrieveFeatureAsHash :name, false
### Getting the data from the dataset
##
# Retrieve an Array for the requested feature
#
# Param 1: Symbol / String. Which feature
# Param 2:  Boolean (Optionaal), should the feature be removed from the dataset?
nameArray = userData.retrieveFeatureAsArray :name, false
```
