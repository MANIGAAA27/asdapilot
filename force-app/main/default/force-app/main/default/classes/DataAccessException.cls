/**
 * @file              DataAccessException.cls
 * @description       Custom exception class for data access errors within the ARMT application.
 *                    Thrown when SOQL queries fail due to FLS, CRUD, or data access violations.
 * @author            ASDA Dev Agent
 * @created           2026-06-06
 * @lastModified      2026-06-06
 * @group             ARMT_Exceptions
 *
 * @dependencies      (none)
 * @calledBy          ARMT_ConfigurationScanner
 * @testClass         ARMT_ConfigurationScannerTest
 *
 * @see               HLD-ARMT-V1.0 Section 3.3
 */

/**
 * Custom exception for data access errors.
 * Thrown when field-level security, CRUD checks, or SOQL operations fail.
 */
public with sharing class DataAccessException extends Exception {
}
