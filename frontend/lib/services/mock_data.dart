import '../models/experiment_plan.dart';
import '../models/literature_review.dart';

const List<String> mockPastConversations = <String>[
  'mRNA vaccine stability under freeze-thaw cycles',
  'CRISPR Cas9 delivery optimization in liver cells',
  'Protein folding assay with fluorescence readout',
  'Cell culture contamination prevention protocol',
];

final LiteratureReview mockLiteratureReviewTemplate = LiteratureReview(
  doesSimilarWorkExist: true,
  totalSources: 8,
  sources: <Source>[
    Source(
      author: 'A. Kim et al.',
      title: 'Optimized cytokine concentrations for T-cell expansion',
      dateOfPublication: DateTime(2022, 7, 12),
      abstractText:
          'This study evaluates cytokine concentrations used in controlled T-cell '
          'expansion experiments and demonstrates reproducible growth outcomes.',
      doi: '10.1126/sciimmunol.22.7812',
    ),
    Source(
      author: 'S. Malik et al.',
      title: 'Serum-free medium effects in long-horizon immune assays',
      dateOfPublication: DateTime(2021, 11, 3),
      abstractText:
          'A multi-site analysis comparing serum-free formulations and their impact '
          'on assay variability, viability, and downstream readout quality.',
      doi: '10.1016/j.omtm.2021.11.003',
    ),
    Source(
      author: 'J. Alvarez et al.',
      title: 'Benchmarking assay setup times across CRO environments',
      dateOfPublication: DateTime(2023, 2, 16),
      abstractText:
          'The authors benchmark setup complexity and schedule risk across CRO '
          'pipelines, with practical estimates for procurement and run time.',
      doi: '10.1038/s41587-023-1202-5',
    ),
    Source(
      author: 'N. Patel et al.',
      title: 'Dose-response planning for early-stage translational studies',
      dateOfPublication: DateTime(2020, 9, 8),
      abstractText:
          'A planning framework linking literature-derived priors with practical '
          'dose-response ranges used by translational science laboratories.',
      doi: '10.1093/nar/gkaa903',
    ),
    Source(
      author: 'M. Chen et al.',
      title: 'Replicate sizing and variance in exploratory preclinical work',
      dateOfPublication: DateTime(2019, 6, 1),
      abstractText:
          'Replicate size strongly influences confidence in exploratory outcomes. '
          'The paper includes recommendations for balancing cost and reliability.',
      doi: '10.1371/journal.pbio.3000459',
    ),
  ],
);

const ExperimentPlan mockExperimentPlan = ExperimentPlan(
  budget: Budget(
    total: 5870.50,
    materials: <Material>[
      Material(
        title: 'Recombinant Cytokine Kit',
        catalogNumber: 'CYT-4902',
        description: 'Cytokine blend for controlled expansion.',
        amount: 2,
        price: 480.00,
      ),
      Material(
        title: 'Serum-Free Medium',
        catalogNumber: 'SFM-1000',
        description: 'Defined medium for immune cell assays.',
        amount: 6,
        price: 145.00,
      ),
      Material(
        title: 'Assay Plates 96-well',
        catalogNumber: 'APL-96-300',
        description: 'Sterile flat-bottom assay plates.',
        amount: 10,
        price: 23.50,
      ),
      Material(
        title: 'Flow Cytometry Antibody Panel',
        catalogNumber: 'FCP-8CLR',
        description: 'Eight-color validation panel.',
        amount: 3,
        price: 620.00,
      ),
      Material(
        title: 'Pipette Tip Rack',
        catalogNumber: 'PTR-200',
        description: 'Filtered, sterile universal tips.',
        amount: 12,
        price: 19.00,
      ),
      Material(
        title: 'Control Compound Set',
        catalogNumber: 'CCS-042',
        description: 'Positive and negative assay controls.',
        amount: 1,
        price: 1720.00,
      ),
    ],
  ),
  timePlan: TimePlan(
    totalDuration: Duration(days: 12, hours: 6),
    steps: <Step>[
      Step(
        number: 1,
        duration: Duration(days: 2),
        name: 'Finalize protocol scope',
        description:
            'Review query constraints, acceptance criteria, and define assay success '
            'metrics with the requesting scientist.',
      ),
      Step(
        number: 2,
        duration: Duration(days: 2, hours: 12),
        name: 'Procure materials',
        description:
            'Order all consumables and reagents, verify catalog substitutions, and '
            'confirm delivery windows with suppliers.',
      ),
      Step(
        number: 3,
        duration: Duration(days: 3),
        name: 'Run pilot experiment',
        description:
            'Execute pilot assay with baseline concentrations and collect first-pass '
            'quality and viability readouts.',
      ),
      Step(
        number: 4,
        duration: Duration(days: 2, hours: 6),
        name: 'Optimize concentration ranges',
        description:
            'Tune dosage windows based on pilot results and run confirmation repeats '
            'for shortlisted conditions.',
      ),
      Step(
        number: 5,
        duration: Duration(days: 2, hours: 12),
        name: 'Prepare lab-ready report',
        description:
            'Compile final timeline, material usage, and validation notes into a '
            'proposal package for lab execution.',
      ),
    ],
  ),
);
