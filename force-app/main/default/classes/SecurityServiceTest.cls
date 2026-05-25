/**
 * SecurityServiceTest
 *
 * Unit tests for SecurityService. Verifies permission-check methods
 * return non-null results and throw exceptions as intended.
 */
@isTest
private class SecurityServiceTest {

    @isTest
    static void hasContentDocumentAccess_returnsNonNull() {
        Test.startTest();
        Boolean result = SecurityService.hasContentDocumentAccess();
        Test.stopTest();
        System.assertNotEquals(null, result, 'hasContentDocumentAccess should return a non-null Boolean');
    }

    @isTest
    static void enforceContentDocumentAccess_doesNotThrowForAdminUser() {
        // Standard test-context users have access to ContentDocument;
        // verify the method completes without throwing.
        Test.startTest();
        try {
            SecurityService.enforceContentDocumentAccess();
            System.assert(true, 'No exception thrown for accessible objects');
        } catch (AuraHandledException ex) {
            System.assert(false, 'Unexpected exception: ' + ex.getMessage());
        }
        Test.stopTest();
    }

    @isTest
    static void isObjectAccessible_accountReturnsTrue() {
        Test.startTest();
        Boolean accessible = SecurityService.isObjectAccessible('Account');
        Test.stopTest();
        System.assertEquals(true, accessible, 'Account should be accessible to the running user');
    }

    @isTest
    static void isObjectAccessible_blankNameReturnsFalse() {
        Test.startTest();
        Boolean accessible = SecurityService.isObjectAccessible('');
        Test.stopTest();
        System.assertEquals(false, accessible, 'Blank object name should return false');
    }

    @isTest
    static void isObjectAccessible_unknownObjectReturnsFalse() {
        Test.startTest();
        Boolean accessible = SecurityService.isObjectAccessible('NonExistentObject__xyz');
        Test.stopTest();
        System.assertEquals(false, accessible, 'Unknown object should return false');
    }
}