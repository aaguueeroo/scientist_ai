// Raw JSON Map fixtures that mirror exactly what the real BE will return.
// These payloads are the canonical reference shape for the BE schema.

const int kMockExpectedTotalSources = 8;

const List<Map<String, dynamic>> kMockSources = <Map<String, dynamic>>[
  <String, dynamic>{
    'author': 'A. Kim et al.',
    'title': 'Optimized cytokine concentrations for T-cell expansion',
    'date_of_publication': '2022-07-12',
    'abstract':
        'This study evaluates cytokine concentrations used in controlled T-cell '
            'expansion experiments and demonstrates reproducible growth outcomes.',
    'doi': '10.1126/sciimmunol.22.7812',
  },
  <String, dynamic>{
    'author': 'S. Malik et al.',
    'title': 'Serum-free medium effects in long-horizon immune assays',
    'date_of_publication': '2021-11-03',
    'abstract':
        'A multi-site analysis comparing serum-free formulations and their impact '
            'on assay variability, viability, and downstream readout quality.',
    'doi': '10.1016/j.omtm.2021.11.003',
  },
  <String, dynamic>{
    'author': 'J. Alvarez et al.',
    'title': 'Benchmarking assay setup times across CRO environments',
    'date_of_publication': '2023-02-16',
    'abstract':
        'The authors benchmark setup complexity and schedule risk across CRO '
            'pipelines, with practical estimates for procurement and run time.',
    'doi': '10.1038/s41587-023-1202-5',
  },
  <String, dynamic>{
    'author': 'N. Patel et al.',
    'title': 'Dose-response planning for early-stage translational studies',
    'date_of_publication': '2020-09-08',
    'abstract':
        'A planning framework linking literature-derived priors with practical '
            'dose-response ranges used by translational science laboratories.',
    'doi': '10.1093/nar/gkaa903',
  },
  <String, dynamic>{
    'author': 'M. Chen et al.',
    'title': 'Replicate sizing and variance in exploratory preclinical work',
    'date_of_publication': '2019-06-01',
    'abstract':
        'Replicate size strongly influences confidence in exploratory outcomes. '
            'The paper includes recommendations for balancing cost and reliability.',
    'doi': '10.1371/journal.pbio.3000459',
  },
];

const Map<String, dynamic> kMockExperimentPlanJson = <String, dynamic>{
  'description':
      'A controlled T-cell expansion assay evaluating cytokine concentration '
          'ranges in serum-free medium, with pilot validation and dose-response '
          'optimization across triplicate conditions.',
  // Steps section is backed by papers 1 and 2 as a whole.
  'steps_section_source_refs': <Map<String, dynamic>>[
    <String, dynamic>{'kind': 'literature', 'reference_index': 1},
    <String, dynamic>{'kind': 'literature', 'reference_index': 2},
  ],
  // Materials section is informed by a previous learning.
  'materials_section_source_refs': <Map<String, dynamic>>[
    <String, dynamic>{'kind': 'previous_learning'},
  ],
  'budget': <String, dynamic>{
    'total': 5870.50,
    'currency': 'USD',
    'materials': <Map<String, dynamic>>[
      <String, dynamic>{
        'title': 'Recombinant Cytokine Kit',
        'catalog_number': 'CYT-4902',
        'description': 'Cytokine blend for controlled expansion.',
        'amount': 2,
        'price': 480.00,
        'source_refs': <Map<String, dynamic>>[
          <String, dynamic>{'kind': 'literature', 'reference_index': 1},
        ],
      },
      <String, dynamic>{
        'title': 'Serum-Free Medium',
        'catalog_number': 'SFM-1000',
        'description': 'Defined medium for immune cell assays.',
        'amount': 6,
        'price': 145.00,
        'source_refs': <Map<String, dynamic>>[
          <String, dynamic>{'kind': 'literature', 'reference_index': 2},
          <String, dynamic>{'kind': 'previous_learning'},
        ],
      },
      <String, dynamic>{
        'title': 'Assay Plates 96-well',
        'catalog_number': 'APL-96-300',
        'description': 'Sterile flat-bottom assay plates.',
        'amount': 10,
        'price': 23.50,
      },
      <String, dynamic>{
        'title': 'Flow Cytometry Antibody Panel',
        'catalog_number': 'FCP-8CLR',
        'description': 'Eight-color validation panel.',
        'amount': 3,
        'price': 620.00,
        'source_refs': <Map<String, dynamic>>[
          <String, dynamic>{'kind': 'literature', 'reference_index': 3},
        ],
      },
      <String, dynamic>{
        'title': 'Pipette Tip Rack',
        'catalog_number': 'PTR-200',
        'description': 'Filtered, sterile universal tips.',
        'amount': 12,
        'price': 19.00,
      },
      <String, dynamic>{
        'title': 'Control Compound Set',
        'catalog_number': 'CCS-042',
        'description': 'Positive and negative assay controls.',
        'amount': 1,
        'price': 1720.00,
        'source_refs': <Map<String, dynamic>>[
          <String, dynamic>{'kind': 'literature', 'reference_index': 4},
          <String, dynamic>{'kind': 'previous_learning'},
        ],
      },
    ],
  },
  'time_plan': <String, dynamic>{
    // 12 days 6 hours.
    'total_duration_seconds': 1058400,
    'steps': <Map<String, dynamic>>[
      <String, dynamic>{
        'number': 1,
        // 2 days.
        'duration_seconds': 172800,
        'name': 'Finalize protocol scope',
        'description':
            'Review query constraints, acceptance criteria, and define assay success '
                'metrics with the requesting scientist.',
        'milestone': 'Protocol approved',
        'source_refs': <Map<String, dynamic>>[
          <String, dynamic>{'kind': 'literature', 'reference_index': 1},
        ],
      },
      <String, dynamic>{
        'number': 2,
        // 2 days 12 hours.
        'duration_seconds': 216000,
        'name': 'Procure materials',
        'description':
            'Order all consumables and reagents, verify catalog substitutions, and '
                'confirm delivery windows with suppliers.',
        'milestone': null,
        'source_refs': <Map<String, dynamic>>[
          <String, dynamic>{'kind': 'previous_learning'},
        ],
      },
      <String, dynamic>{
        'number': 3,
        // 3 days.
        'duration_seconds': 259200,
        'name': 'Run pilot experiment',
        'description':
            'Execute pilot assay with baseline concentrations and collect first-pass '
                'quality and viability readouts.',
        'milestone': 'Pilot data collected',
        'source_refs': <Map<String, dynamic>>[
          <String, dynamic>{'kind': 'literature', 'reference_index': 1},
          <String, dynamic>{'kind': 'literature', 'reference_index': 2},
        ],
      },
      <String, dynamic>{
        'number': 4,
        // 2 days 6 hours.
        'duration_seconds': 194400,
        'name': 'Optimize concentration ranges',
        'description':
            'Tune dosage windows based on pilot results and run confirmation repeats '
                'for shortlisted conditions.',
        'milestone': null,
        'source_refs': <Map<String, dynamic>>[
          <String, dynamic>{'kind': 'literature', 'reference_index': 3},
          <String, dynamic>{'kind': 'literature', 'reference_index': 5},
        ],
      },
      <String, dynamic>{
        'number': 5,
        // 2 days 12 hours.
        'duration_seconds': 216000,
        'name': 'Prepare lab-ready report',
        'description':
            'Compile final timeline, material usage, and validation notes into a '
                'proposal package for lab execution.',
        'milestone': 'Report delivered',
      },
    ],
  },
  'risks': <Map<String, dynamic>>[
    <String, dynamic>{
      'description':
          'Cytokine lot variability may shift baseline expansion rates, '
              'invalidating concentration thresholds established in the pilot.',
      'likelihood': 'medium',
      'mitigation':
          'Reserve one vial from each lot for inter-lot control runs; '
              'repeat baseline measurement if CV across replicates exceeds 15%.',
    },
    <String, dynamic>{
      'description':
          'Supplier lead times for Recombinant Cytokine Kit (CYT-4902) '
              'could delay the pilot by up to five business days.',
      'likelihood': 'low',
      'mitigation':
          'Place order at least two weeks before the scheduled pilot start '
              'and identify one pre-qualified alternate vendor.',
    },
  ],
};
