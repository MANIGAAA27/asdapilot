# Partner Registration Automation - Project Requirements

## Overview
This project automates the creation and synchronization of Opportunity records from Deal Registration records.

## Functional Requirements

### 1. Automatic Opportunity Creation
- **Trigger**: When a new Deal Registration record is created
- **Action**: Automatically create a corresponding Opportunity record
- **Linking**: Establish bi-directional lookup relationship between the two records

### 2. Field Mappings
Field mappings are managed via Custom Metadata Type to allow configuration without code changes:

| Deal Registration Field | Opportunity Field |
|------------------------|-------------------|
| Partner Account | AccountId |
| Primary Partner Contact | Primary_Contact__c |
| Estimated Deal Value | Amount |
| Projected Close Date | CloseDate |
| Description | Description |

### 3. Synchronization Rules
- **Active Sync**: Updates to mapped fields on Deal Registration automatically sync to the linked Opportunity
- **Sync Termination**: Synchronization stops when Deal Registration status changes to 'Approved'
- **Lock Behavior**: Once 'Approved', the Opportunity is locked from further updates originating from the Deal Registration

## Acceptance Criteria

1. ✅ When a new Deal Registration record is created, a new Opportunity record is automatically created and linked
2. ✅ The source Deal Registration record's lookup field is populated with the new Opportunity ID, and the new Opportunity's lookup field is populated with the source Deal Registration ID
3. ✅ The new Opportunity's fields are populated with values from the source Deal Registration, according to the mappings defined in the custom metadata type
4. ✅ When mapped fields on an active (not 'Approved') Deal Registration are updated, the corresponding Opportunity fields are updated automatically
5. ✅ When a Deal Registration status is changed to 'Approved', subsequent updates to mapped fields do NOT sync to the Opportunity
6. ✅ All Apex code has 85%+ test coverage with meaningful assertions
7. ✅ All custom metadata, fields, and objects are deployable via SFDX

## Technical Architecture

### Custom Objects Required
- **Deal_Registration__c** (if not exists)
  - Fields: Partner_Account__c, Primary_Partner_Contact__c, Estimated_Deal_Value__c, Projected_Close_Date__c, Description__c, Status__c, Linked_Opportunity__c
  
### Custom Metadata Type
- **Deal_Registration_Field_Mapping__mdt**
  - Fields: Deal_Registration_Field__c, Opportunity_Field__c, Is_Active__c

### Apex Components
- **DealRegistrationTrigger** - Trigger on Deal_Registration__c (after insert, after update)
- **DealRegistrationTriggerHandler** - Handler class with trigger logic
- **DealRegistrationSyncService** - Service class for sync operations
- **FieldMappingService** - Utility to read custom metadata mappings

### Test Classes
- **DealRegistrationTriggerHandlerTest** - 85%+ coverage
- **DealRegistrationSyncServiceTest** - 85%+ coverage
- **FieldMappingServiceTest** - 85%+ coverage