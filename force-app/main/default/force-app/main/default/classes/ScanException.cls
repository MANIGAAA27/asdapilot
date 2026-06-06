/**
 * @file              ScanException.cls
 * @description       Custom exception class for scan and processing errors within the ARMT application.
 *                    Thrown when configuration scanning operations encounter unexpected failures.
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
 * Custom exception for scan and processing errors.
 * Thrown when configuration scanning operations fail unexpectedly.
 */
public with sharing class ScanException extends Exception {
}
