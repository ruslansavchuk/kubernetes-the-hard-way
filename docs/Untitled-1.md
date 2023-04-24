db changes after release:
  - table: subscripsion
    changes:
      - EnableLoggingFunctionality remove
      - SendLogNotifications remove

  - table: FragmentSettings
    changes: remove
  - table: FragmentResults
    changes: remove
  - table: PrecalculatedFragmentResults
    changes: remove

  - table: Components
    changes: remove
  - table: ScoreProductResults
    changes: remove
  - table: PrecalculatedScoreResults
    changes: remove

  - table: DatasetInsights
    changes: remove
  - table: PrecalculatedDatasetInsights
    changes: remove

  - table: ScoringEngineVerifications
    changes: remove
  - table: ScoringEngineVerificationItems
    changes: remove
  - table: Profiles
    changes: remove
  - table: ProfileFields
    changes: remove

  - table: WebDatasetChunks
    changes: removed
  - table: WebEnvironments
    changes: removed
  - table: WebDatasets
    changes: remove

  - table: MobileDatasets
    changes:
      - FileSize remove
      - SdkIdentifier remove

  - table: Datasets
    changes:
      - IX_JsonId - remove index
      - JsonId - remove column
