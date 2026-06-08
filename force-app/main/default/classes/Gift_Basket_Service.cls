/**
 * @file              Gift_Basket_Service.cls
 * @description       Service layer for the Gift Basket feature. Handles sending the
 *                    shipping request email when a gift basket form is submitted, and
 *                    exposes the gift basket offer data for LWC components.
 * @author            ASDA Dev Agent (Claude Code)
 * @created           2026-06-08
 * @lastModified      2026-06-08
 * @group             GiftBasket
 *
 * @dependencies      Gift_Basket_Request__c
 * @calledBy          Gift_Basket_Screen_Flow, Recipient_Information_Flow
 * @testClass         Gift_Basket_ServiceTest
 *
 * @project           Gift Basket
 * @lld               LLD-GiftBasket
 */
public without sharing class Gift_Basket_Service {

    /**
     * Wrapper class for the Flow @InvocableMethod input parameter.
     * Maps the Flow's requestId input parameter to the Apex invocable method.
     */
    public class SendEmailRequest {
        @InvocableVariable(label='Request ID' required=true)
        public Id requestId;
    }

    /**
     * Inner class representing the result of an email send attempt.
     * Retained for internal use and unit test assertions.
     */
    public class ShippingEmailResult {
        @AuraEnabled public Boolean success;
        @AuraEnabled public String errorMessage;
    }

    /**
     * Invocable method called by the Gift Basket Screen Flow and Recipient Information
     * Flow after a Gift Basket Request record is created. Sends a shipping request
     * email to the shipping department for each request in the batch.
     *
     * @param  requests  List of SendEmailRequest wrappers containing the Gift Basket
     *                   Request record IDs to process.
     *
     * @calledBy    Gift_Basket_Screen_Flow, Recipient_Information_Flow
     * @testMethods testSendShippingRequestEmail_success, testSendShippingRequestEmail_nullId
     */
    @InvocableMethod(label='Send Shipping Request Email'
                     description='Sends the gift basket shipping request email to the shipping department')
    public static void sendShippingRequestEmail(List<SendEmailRequest> requests) {
        for (SendEmailRequest req : requests) {
            if (req != null && req.requestId != null) {
                processSendEmail(req.requestId);
            }
        }
    }

    /**
     * Core email dispatch logic. Queries the Gift Basket Request record, builds
     * the email body, and sends via Messaging.sendEmail.
     *
     * @param requestId  Id of the Gift_Basket_Request__c to process.
     * @return           ShippingEmailResult indicating success or failure.
     */
    @TestVisible
    private static ShippingEmailResult processSendEmail(Id requestId) {
        ShippingEmailResult result = new ShippingEmailResult();
        try {
            Gift_Basket_Request__c requestRecord = [
                SELECT Id, Name, Account__c, Account__r.Name, Recipient_Name__c,
                       Street_Address__c, City__c, State_Province__c, Postal_Code__c,
                       Country__c, Status__c, Submitted_By__c, Submitted_By__r.Name,
                       Submission_Date_Time__c, Full_Address__c
                FROM Gift_Basket_Request__c
                WHERE Id = :requestId
                LIMIT 1
            ];

            String toAddress = 'shipping@example.com';
            Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
            email.setToAddresses(new String[] { toAddress });
            email.setSubject('Gift Basket Request - ' + requestRecord.Account__r.Name);
            email.setPlainTextBody(buildEmailBody(requestRecord));
            email.setSaveAsActivity(false);

            Messaging.SendEmailResult[] sendResults = Messaging.sendEmail(
                new Messaging.SingleEmailMessage[] { email }, false
            );
            if (sendResults != null && !sendResults.isEmpty() && sendResults[0].isSuccess()) {
                result.success = true;
                result.errorMessage = null;
            } else {
                result.success = false;
                result.errorMessage = 'Email delivery failed.';
            }
        } catch (Exception ex) {
            result.success = false;
            result.errorMessage = ex.getMessage();
        }
        return result;
    }

    /** Assembles the plain-text email body from the Gift Basket Request record fields. */
    private static String buildEmailBody(Gift_Basket_Request__c requestRecord) {
        List<String> lines = new List<String>();
        lines.add('Account Name: ' + (requestRecord.Account__r != null ? requestRecord.Account__r.Name : ''));
        lines.add('Recipient Name: ' + requestRecord.Recipient_Name__c);
        lines.add('Street Address: ' + requestRecord.Street_Address__c);
        lines.add('City: ' + requestRecord.City__c);
        lines.add('State/Province: ' + requestRecord.State_Province__c);
        lines.add('Postal Code: ' + requestRecord.Postal_Code__c);
        lines.add('Country: ' + requestRecord.Country__c);
        lines.add('Submitted By: ' + (requestRecord.Submitted_By__r != null ? requestRecord.Submitted_By__r.Name : ''));
        lines.add('Submission Date: ' + String.valueOf(requestRecord.Submission_Date_Time__c));
        lines.add('Full Address: ' + requestRecord.Full_Address__c);
        return String.join(lines, '\n');
    }

    /**
     * Returns the gift basket offer details for display in LWC NBA component.
     *
     * @return  List of GiftBasketOfferWrapper with offer title, description, and eligibility.
     *
     * @calledBy    (none in this changeset)
     * @testMethods testGetGiftBasketOffer
     */
    @AuraEnabled(cacheable=true)
    public static List<GiftBasketOfferWrapper> getGiftBasketOffer() {
        List<GiftBasketOfferWrapper> offers = new List<GiftBasketOfferWrapper>();
        offers.add(new GiftBasketOfferWrapper('Gift Basket Offer', 'Offer a complimentary gift basket.', true));
        return offers;
    }

    /** Wrapper for gift basket offer data surfaced to LWC components. */
    public class GiftBasketOfferWrapper {
        @AuraEnabled public String title;
        @AuraEnabled public String description;
        @AuraEnabled public Boolean eligible;

        public GiftBasketOfferWrapper(String title, String description, Boolean eligible) {
            this.title = title;
            this.description = description;
            this.eligible = eligible;
        }
    }
}
