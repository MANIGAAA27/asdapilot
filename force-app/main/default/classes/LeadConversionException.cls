/**
 * @file              LeadConversionException.cls
 * @description       Custom exception class for the LWC Lead Conversion solution.
 *                    Thrown by LeadConversionService and LeadMatchingUtil to provide
 *                    clear, user-friendly error messages surfaced via AuraHandledException
 *                    in the controller.
 * @author            ASDA Dev Agent
 * @created           2026-05-28
 * @lastModified      2026-05-28
 * @group             LeadConversion
 *
 * @dependencies      (none)
 * @calledBy          LeadConversionService, LeadMatchingUtil, LeadConversionController
 * @testClass         LeadConversionServiceTest
 *
 * @see               LLD - LWC Lead Conversion (Keneland Technology)
 */
public with sharing class LeadConversionException extends Exception {
}
