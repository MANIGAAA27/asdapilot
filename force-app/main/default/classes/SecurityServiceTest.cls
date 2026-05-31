/**
 * @file        SecurityServiceTest.cls
 * @description Tests SecurityService field-level security checks
 * @testFor     SecurityService
 * @coverage    Target >= 90%
 */
@isTest
private class SecurityServiceTest {

    @isTest
    static void test_hasFieldReadAccess_validFields_returnsTrue() {
        Test.startTest();
        Boolean result = SecurityService.hasFieldReadAccess('Case', new List<String>{'Id', 'Subject', 'Status'});
        Test.stopTest();
        
        System.assert(result, 'Should have read access to standard Case fields');
    }

    @isTest
    static void test_hasFieldUpdateAccess_validFields_returnsTrue() {
        Test.startTest();
        Boolean result = SecurityService.hasFieldUpdateAccess('Case', new List<String>{'Subject', 'Status'});
        Test.stopTest();
        
        System.assert(result, 'Should have update access to editable Case fields');
    }

    @isTest
    static void test_hasFieldReadAccess_invalidField_returnsFalse() {
        Test.startTest();
        Boolean result = SecurityService.hasFieldReadAccess('Case', new List<String>{'NonExistentField__c'});
        Test.stopTest();
        
        System.assertEquals(false, result, 'Should return false for non-existent field');
    }
}
