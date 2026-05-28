/**
  @file              CaseTransferSummaryControllerTest.cls
  @description       Unit test for CaseTransferSummaryController class. Tests all logical paths: success, no record, and no access.
  @testFor           CaseTransferSummaryController
  @coverage          Goal: 100% Line and Branch Coverage
  @author            Yuki Tanaka
  @lastModified      2024-03-21
 */
@isTest
private class CaseTransferSummaryControllerTest {
    
    @testSetup
    static void setup() {
        Case testCaseWithSummary = new Case(