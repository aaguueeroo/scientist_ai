// Seed `Review` JSON payloads used by `MockScientistBackendClient`. Each
// review embeds a self-contained `original_plan` snapshot (with stable
// `id` fields on every step/material) so that targets like
// `step[step_seed_1].name` resolve correctly when the FE re-parses the
// review back into a domain object.

const String _kSeedConversation1 =
    'mRNA vaccine stability under freeze-thaw cycles';
const String _kSeedConversation2 =
    'CRISPR Cas9 delivery optimization in liver cells';
const String _kSeedConversation3 =
    'Protein folding assay with fluorescence readout';

const Map<String, dynamic> _kSeedPlan1 = <String, dynamic>{
  'description':
      'Evaluate mRNA vaccine stability across multiple freeze-thaw '
          'cycles using a controlled cold-chain protocol with HPLC '
          'integrity checkpoints.',
  'budget': <String, dynamic>{
    'total': 4280.00,
    'currency': 'USD',
    'materials': <Map<String, dynamic>>[
      <String, dynamic>{
        'id': 'mat_seed_1_a',
        'title': 'Lipid Nanoparticle Kit',
        'catalog_number': 'LNP-220',
        'description': 'Standard formulation kit for mRNA encapsulation.',
        'amount': 2,
        'price': 720.00,
      },
      <String, dynamic>{
        'id': 'mat_seed_1_b',
        'title': 'HPLC Integrity Column',
        'catalog_number': 'HPLC-INT-08',
        'description': 'For mRNA strand integrity quantification.',
        'amount': 1,
        'price': 1840.00,
      },
    ],
  },
  'time_plan': <String, dynamic>{
    'total_duration_seconds': 691200,
    'steps': <Map<String, dynamic>>[
      <String, dynamic>{
        'id': 'step_seed_1_a',
        'number': 1,
        'duration_seconds': 86400,
        'name': 'Prepare cold-chain stations',
        'description':
            'Calibrate freezers and confirm temperature logging.',
        'milestone': null,
      },
      <String, dynamic>{
        'id': 'step_seed_1_b',
        'number': 2,
        'duration_seconds': 432000,
        'name': 'Run freeze-thaw cycles',
        'description':
            'Cycle samples five times with 12-hour holds and intermediate '
                'integrity readings.',
        'milestone': 'All cycles complete',
      },
      <String, dynamic>{
        'id': 'step_seed_1_c',
        'number': 3,
        'duration_seconds': 172800,
        'name': 'Analyze and report',
        'description':
            'Run HPLC reads and produce stability conclusions.',
        'milestone': 'Report delivered',
      },
    ],
  },
};

const Map<String, dynamic> _kSeedPlan2 = <String, dynamic>{
  'description':
      'Optimize Cas9 RNP delivery to primary hepatocytes by varying '
          'electroporation conditions and lipid carriers.',
  'budget': <String, dynamic>{
    'total': 6120.00,
    'currency': 'USD',
    'materials': <Map<String, dynamic>>[
      <String, dynamic>{
        'id': 'mat_seed_2_a',
        'title': 'Cas9 RNP Bundle',
        'catalog_number': 'CRISPR-RNP-12',
        'description': 'High-fidelity Cas9 with sgRNA pool.',
        'amount': 3,
        'price': 1280.00,
      },
    ],
  },
  'time_plan': <String, dynamic>{
    'total_duration_seconds': 432000,
    'steps': <Map<String, dynamic>>[
      <String, dynamic>{
        'id': 'step_seed_2_a',
        'number': 1,
        'duration_seconds': 172800,
        'name': 'Source primary hepatocytes',
        'description':
            'Confirm donor batch and viability QC before electroporation.',
        'milestone': null,
      },
      <String, dynamic>{
        'id': 'step_seed_2_b',
        'number': 2,
        'duration_seconds': 259200,
        'name': 'Run delivery matrix',
        'description':
            'Test five electroporation conditions across two carriers.',
        'milestone': 'Editing efficiencies measured',
      },
    ],
  },
};

const Map<String, dynamic> _kSeedPlan3 = <String, dynamic>{
  'description':
      'A real-time fluorescence readout of protein folding kinetics with '
          'thermal unfolding controls.',
  'budget': <String, dynamic>{
    'total': 2150.00,
    'currency': 'USD',
    'materials': <Map<String, dynamic>>[
      <String, dynamic>{
        'id': 'mat_seed_3_a',
        'title': 'Fluorescent Probe Set',
        'catalog_number': 'FPB-310',
        'description': 'Environment-sensitive folding probes.',
        'amount': 4,
        'price': 280.00,
      },
    ],
  },
  'time_plan': <String, dynamic>{
    'total_duration_seconds': 345600,
    'steps': <Map<String, dynamic>>[
      <String, dynamic>{
        'id': 'step_seed_3_a',
        'number': 1,
        'duration_seconds': 172800,
        'name': 'Plate and prime samples',
        'description': 'Distribute proteins and probes across replicates.',
        'milestone': null,
      },
      <String, dynamic>{
        'id': 'step_seed_3_b',
        'number': 2,
        'duration_seconds': 172800,
        'name': 'Run thermal sweep',
        'description':
            'Capture folding curves across the working temperature range.',
        'milestone': 'Curves captured',
      },
    ],
  },
};

/// Seed reviews returned by `GET /reviews` on a fresh app load.
const List<Map<String, dynamic>> kMockSeedReviews = <Map<String, dynamic>>[
  <String, dynamic>{
    'id': 'review_seed_1',
    'created_at': '2026-04-25T15:32:11Z',
    'conversation_id': _kSeedConversation1,
    'query': _kSeedConversation1,
    'original_plan': _kSeedPlan1,
    'kind': 'correction',
    'payload': <String, dynamic>{
      'target': 'step[step_seed_1_b].name',
      'before': 'Run freeze-thaw cycles',
      'after': 'Run freeze-thaw cycles with intermediate integrity reads',
    },
  },
  <String, dynamic>{
    'id': 'review_seed_2',
    'created_at': '2026-04-25T15:40:02Z',
    'conversation_id': _kSeedConversation1,
    'query': _kSeedConversation1,
    'original_plan': _kSeedPlan1,
    'kind': 'feedback',
    'payload': <String, dynamic>{
      'section': 'budget',
      'polarity': 'dislike',
    },
  },
  <String, dynamic>{
    'id': 'review_seed_3',
    'created_at': '2026-04-26T10:11:48Z',
    'conversation_id': _kSeedConversation2,
    'query': _kSeedConversation2,
    'original_plan': _kSeedPlan2,
    'kind': 'comment',
    'payload': <String, dynamic>{
      'target': 'plan.description',
      'quote': 'electroporation conditions',
      'start': 64,
      'end': 89,
      'body': 'Specify which electroporation device the lab will use.',
    },
  },
  <String, dynamic>{
    'id': 'review_seed_4',
    'created_at': '2026-04-26T11:02:30Z',
    'conversation_id': _kSeedConversation2,
    'query': _kSeedConversation2,
    'original_plan': _kSeedPlan2,
    'kind': 'feedback',
    'payload': <String, dynamic>{
      'section': 'steps',
      'polarity': 'like',
    },
  },
  <String, dynamic>{
    'id': 'review_seed_5',
    'created_at': '2026-04-26T18:45:09Z',
    'conversation_id': _kSeedConversation3,
    'query': _kSeedConversation3,
    'original_plan': _kSeedPlan3,
    'kind': 'correction',
    'payload': <String, dynamic>{
      'target': 'plan.budget.total',
      'before': 2150.00,
      'after': 2380.00,
    },
  },
  <String, dynamic>{
    'id': 'review_seed_6',
    'created_at': '2026-04-26T19:01:54Z',
    'conversation_id': _kSeedConversation3,
    'query': _kSeedConversation3,
    'original_plan': _kSeedPlan3,
    'kind': 'comment',
    'payload': <String, dynamic>{
      'target': 'step[step_seed_3_a].description',
      'quote': 'Distribute proteins and probes',
      'start': 0,
      'end': 30,
      'body': 'Add a sterility QC checkpoint before plating.',
    },
  },
];
