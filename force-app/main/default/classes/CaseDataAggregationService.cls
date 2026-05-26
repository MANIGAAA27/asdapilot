/**
 * @file              CaseDataAggregationService.cls
 * @description       Aggregates all case-related data up to a given transfer
 *                    timestamp. Queries EmailMessages, CaseComments, and
 *                    CaseHistory for the specified case. Data created after the
 *                    transfer timestamp is excluded so the LLM payload reflects
 *                    only context available at the moment of transfer.
 * @author            ASDA Dev Agent (Claude Code)
 * @created           2026-05-25
 * @lastModified      2026-05-25
 * @group             CaseSummaryTransfer
 *
 * @dependencies      (none in this changeset)
 * @calledBy          CaseSummaryTransferQueueable
 * @testClass         CaseDataAggregationServiceTest
 *
 * @see               LLD-Case Summary Transfer 1.0 §2.2 Data Aggregation Service
 */
public with sharing class CaseDataAggregationService {

    /**
     * Aggregates all case data relevant to the transfer context.
     * Queries are filtered to exclude records created after transferTimestamp
     * to maintain payload relevance per FR7.
     *
     * @param  caseId             Id of the Case to aggregate data for.
     * @param  transferTimestamp  Cutoff DateTime; data after this is excluded.
     * @return Map with keys: caseRecord (Case), emails (List<EmailMessage>),
     *         comments (List<CaseComment>), history (List<CaseHistory>).
     *         Never returns null; individual list values may be empty.
     * @throws AuraHandledException if the Case does not exist.
     *
     * @calledBy    CaseSummaryTransferQueueable.execute
     * @testMethods test_aggregateCaseData_validCaseId_returnsAggregatedData,
     *              test_aggregateCaseData_excludesDataAfterTransfer_correctlyFilters
     */
    public static Map<String, Object> aggregateCaseData(Id caseId, DateTime transferTimestamp) {
        List<Case> cases = [
            SELECT Id, CaseNumber, Subject, Description, Status, Priority,
                   OwnerId, AccountId, ContactId, CreatedDate, LastModifiedDate
            FROM   Case
            WHERE  Id = :caseId
            WITH SECURITY_ENFORCED
        ];

        if (cases.isEmpty()) {
            throw new CaseDataAggregationServiceException(
                'No Case found for Id: ' + caseId
            );
        }

        List<EmailMessage> emails = [
            SELECT Id, Subject, TextBody, FromAddress, ToAddress, MessageDate, Incoming
            FROM   EmailMessage
            WHERE  ParentId = :caseId
            AND    MessageDate <= :transferTimestamp
            WITH SECURITY_ENFORCED
            ORDER BY MessageDate ASC
        ];

        List<CaseComment> comments = [
            SELECT Id, CommentBody, CreatedDate, CreatedById, IsPublished
            FROM   CaseComment
            WHERE  ParentId = :caseId
            AND    CreatedDate <= :transferTimestamp
            WITH SECURITY_ENFORCED
            ORDER BY CreatedDate ASC
        ];

        List<CaseHistory> history = [
            SELECT Id, Field, OldValue, NewValue, CreatedDate, CreatedById
            FROM   CaseHistory
            WHERE  CaseId = :caseId
            AND    CreatedDate <= :transferTimestamp
            ORDER BY CreatedDate ASC
        ];

        return new Map<String, Object>{
            'caseRecord' => cases[0],
            'emails'     => emails,
            'comments'   => comments,
            'history'    => history
        };
    }

    /** Custom exception for aggregation failures. */
    public class CaseDataAggregationServiceException extends Exception {}
}