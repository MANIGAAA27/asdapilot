/**
  @file              LlmApiException.cls
  @description       Custom exception for handling errors related to LlmApiCalloutService operations, including detailed error messages for debugging.
  @author            ASDA Dev Agent
  @lastModified      2023-10-10
  @dependencies      (none in this changeset)
  @calledBy          LlmApiCalloutService.summarizeCase
  @testClass         LlmApiCalloutServiceTest
 */
public class LlmApiException extends Exception {}