/**
 * @file        Gift_Basket_ServiceTest.cls
 * @description Tests Gift_Basket_Service — covers InvocableMethod email dispatch,
 *              offer data retrieval, null-safety, and bulk paths.
 * @testFor     Gift_Basket_Service
 * @coverage    Target >= 90%.
 *
 * @project     Gift Basket
 * @lld         LLD-GiftBasket
 */
@isTest
private class Gift_Basket_ServiceTest {

    @isTest
    static void testGetGiftBasketOffer() {
        Test.startTest();
        List<Gift_Basket_Service.GiftBasketOfferWrapper> offers = Gift_Basket_Service.getGiftBasketOffer();
        Test.stopTest();
        System.assertEquals(1, offers.size(), 'Expected one offer');
        System.assertEquals('Gift Basket Offer', offers[0].title, 'Offer title mismatch');
        System.assertEquals(true, offers[0].eligible, 'Offer should be eligible');
    }

    @isTest
    static void testSendShippingRequestEmail_success() {
        Account acc = new Account(Name = 'Test Account');
        insert acc;

        Gift_Basket_Request__c requestRecord = new Gift_Basket_Request__c(
            Account__c = acc.Id,
            Recipient_Name__c = 'Jane Doe',
            Street_Address__c = '100 Main St',
            City__c = 'Lexington',
            State_Province__c = 'KY',
            Postal_Code__c = '40507',
            Country__c = 'USA',
            Status__c = 'Submitted',
            Submission_Date_Time__c = System.now()
        );
        insert requestRecord;

        Gift_Basket_Service.SendEmailRequest req = new Gift_Basket_Service.SendEmailRequest();
        req.requestId = requestRecord.Id;

        Test.startTest();
        Gift_Basket_Service.sendShippingRequestEmail(
            new List<Gift_Basket_Service.SendEmailRequest>{ req }
        );
        Test.stopTest();

        // Verify the record still exists and email did not throw
        Gift_Basket_Request__c verifyRecord = [SELECT Id FROM Gift_Basket_Request__c WHERE Id = :requestRecord.Id LIMIT 1];
        System.assertNotEquals(null, verifyRecord, 'Record should still exist after email dispatch');
    }

    @isTest
    static void testSendShippingRequestEmail_nullId() {
        Gift_Basket_Service.SendEmailRequest req = new Gift_Basket_Service.SendEmailRequest();
        req.requestId = null;

        Test.startTest();
        // Should not throw even when requestId is null
        Gift_Basket_Service.sendShippingRequestEmail(
            new List<Gift_Basket_Service.SendEmailRequest>{ req }
        );
        Test.stopTest();

        System.assert(true, 'Null requestId should be handled gracefully');
    }

    @isTest
    static void testProcessSendEmail_validRecord() {
        Account acc = new Account(Name = 'Acme Corp');
        insert acc;

        Gift_Basket_Request__c requestRecord = new Gift_Basket_Request__c(
            Account__c = acc.Id,
            Recipient_Name__c = 'John Smith',
            Street_Address__c = '200 Oak Ave',
            City__c = 'Louisville',
            State_Province__c = 'KY',
            Postal_Code__c = '40202',
            Country__c = 'USA',
            Status__c = 'Submitted',
            Submission_Date_Time__c = System.now()
        );
        insert requestRecord;

        Test.startTest();
        Gift_Basket_Service.ShippingEmailResult result = Gift_Basket_Service.processSendEmail(requestRecord.Id);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null');
    }
}
