#!/bin/bash

source ./.env

# Prepare names
uniquestring=$(echo $RANDOM | tr '[0-9]' '[a-z]')

# Name of the new Digital Twin
export dtname="${prefix}-dt-${uniquestring}"


# login
#az login --tenant $tenant_id
az account set --subscription $subscription_id

# Create resoruce group or reuse an existing one
#az group create -n $rgname -l $location

# Create Azure Digital Twins
az dt create --dt-name $dtname -g $rgname -l $location --mi-system-assigned true

# In order to modify the Azure Digital Twins service, you'll need to assign the Azure Digital Twins Owner permission
az dt role-assignment create -n $dtname -g $rgname --role "Azure Digital Twins Data Owner" --assignee $username -o json

# Get the hostname of the Digital Twins instance. Copy the output to notepad for use later.
az dt show -n $dtname --query 'hostName'

# Get the Azure Active Directory (AAD) Tenant ID
#az account show --query 'tenantId'

#
# For Data history
#

# Connection name can contain letters, numbers, and hyphens. It must contain at least one letter, and be between 3 and 50 characters long.
connectionname="dt-history-conn01"

## Event Hub Setup
# Namespace can contain letters, numbers, and hyphens. It must start with a letter, end with a letter or number, and be between 6 and 50 characters long.
eventhubnamespace="${prefix}-ehns-${uniquestring}"

# Event hub name can contain only letters, numbers, periods, hyphens and underscores. It must start and end with a letter or number.
eventhub="dteventhub"

## Azure Data Explorer Setup

# Cluster name can contain only lowercase alphanumeric characters. It must start with a letter, and be between 4 and 22 characters long.
clustername="${prefix}adx${uniquestring}"  

# Database name can contain only alphanumeric, spaces, dash and dot characters, and be up to 260 characters in length.
databasename="dtdb"

# Create an Event Hubs namespace
az eventhubs namespace create --name $eventhubnamespace --resource-group $rgname --location $location

# Create an event hub in your namespace:
az eventhubs eventhub create --name $eventhub --resource-group $rgname --namespace-name $eventhubnamespace

# Create a Kusto (Azure Data Explorer) cluster and database
az extension add --name kusto
az kusto cluster create --cluster-name $clustername --sku name="Dev(No SLA)_Standard_E2a_v4" tier="Basic" --resource-group $rgname --location $location --type SystemAssigned
az kusto database create --cluster-name $clustername --database-name $databasename --resource-group $rgname --read-write-database soft-delete-period=P365D hot-cache-period=P31D location=$location

# Set up data history connection
az dt data-history connection create adx --cn $connectionname --dt-name $dtname --adx-cluster-name $clustername --adx-database-name $databasename --eventhub $eventhub --eventhub-namespace $eventhubnamespace

#
# For Loading sample model
#

# Create/uplod models to DT
homemodelid=$(az dt model create -n $dtname --models ../models/IHome.json --query [].id -o tsv)
floormodelid=$(az dt model create -n $dtname --models ../models/IFloor.json --query [].id -o tsv)
roommodelid=$(az dt model create -n $dtname --models ../models/IRoom.json --query [].id -o tsv)
sensormodelid=$(az dt model create -n $dtname --models ../models/ISensor.json --query [].id -o tsv)

# Once the models are successfully uploaded, use the following commands to create Twin instances
az dt twin create -n $dtname --dtmi $homemodelid --twin-id "MyHome"
az dt twin create -n $dtname --dtmi $floormodelid --twin-id "Floor-00"
az dt twin create -n $dtname --dtmi $roommodelid --twin-id "LivingRoom-00-01"
az dt twin create -n $dtname --dtmi $sensormodelid --twin-id "Sensor-00-01-01"

# Next we'll need to establish how the models relate to each other.
# To setup the relationships between twin instances, we must identify the relationship definitions in the models (.json documents) 
# that were uploaded. In the case of the Home / Floor / Room, the relationship name is "rel_has_floors"

# Relationship
# Now that we know the relationship that we want to establish, run the commands below to instantiate the relationships.
relname="rel_has_floors"
az dt twin relationship create -n $dtname --relationship $relname --twin-id "MyHome" --target "Floor-00" --relationship-id "Home has floors"
relname="rel_has_rooms"
az dt twin relationship create -n $dtname --relationship $relname --twin-id "Floor-00" --target "LivingRoom-00-01" --relationship-id "Floor has rooms"
relname="rel_has_sensors"
az dt twin relationship create -n $dtname --relationship $relname --twin-id "LivingRoom-00-01" --target "Sensor-00-01-01" --relationship-id "Room has sensors"
