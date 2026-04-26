import '../../core/id_generator.dart';
import '../../models/experiment_plan.dart';
import '../../models/project.dart';

/// Builds the in-memory list of mock ongoing projects shown in the sidebar.
///
/// Each project has its own [ExperimentPlan] (intentionally similar across
/// projects so the timeline + step layout is recognisable) and a different
/// completion + attachment state so both roles have something to interact
/// with on first launch.
List<Project> buildMockProjects() {
  final DateTime now = DateTime.now();
  return <Project>[
    _buildMrnaProject(now),
    _buildCrisprProject(now),
    _buildProteinFoldingProject(now),
  ];
}

Project _buildMrnaProject(DateTime now) {
  final ExperimentPlan plan = _buildPlanA();
  return Project(
    id: 'project_mrna_freeze_thaw',
    title: 'mRNA stability under freeze-thaw cycles',
    assignedScientistName: 'Alex Chen',
    assignedScientistAvatarUrl: 'https://i.pravatar.cc/120?u=alex-chen',
    labName: 'BioReady Labs',
    startedAt: now.subtract(const Duration(days: 14)),
    lastUpdatedAt: now.subtract(const Duration(hours: 9)),
    plan: plan,
    stepCompletion: <String, bool>{
      plan.timePlan.steps[0].id: true,
      plan.timePlan.steps[1].id: true,
      plan.timePlan.steps[2].id: true,
    },
    stepAttachments: <String, List<ProjectAttachment>>{
      plan.timePlan.steps[0].id: <ProjectAttachment>[
        ProjectAttachment(
          fileName: 'protocol_scope_v3.pdf',
          sizeBytes: 482_133,
          addedAt: now.subtract(const Duration(days: 12)),
        ),
      ],
      plan.timePlan.steps[2].id: <ProjectAttachment>[
        ProjectAttachment(
          fileName: 'pilot_run_readout.csv',
          sizeBytes: 1_204_550,
          addedAt: now.subtract(const Duration(days: 4)),
        ),
        ProjectAttachment(
          fileName: 'pilot_quality_checks.xlsx',
          sizeBytes: 89_220,
          addedAt: now.subtract(const Duration(days: 4)),
        ),
      ],
    },
  );
}

Project _buildCrisprProject(DateTime now) {
  final ExperimentPlan plan = _buildPlanB();
  return Project(
    id: 'project_crispr_liver',
    title: 'CRISPR Cas9 delivery in liver cells',
    assignedScientistName: 'Maya Rivera',
    assignedScientistAvatarUrl: 'https://i.pravatar.cc/120?u=maya-rivera',
    labName: 'Helix CRO',
    startedAt: now.subtract(const Duration(days: 4)),
    lastUpdatedAt: now.subtract(const Duration(hours: 28)),
    plan: plan,
    stepCompletion: <String, bool>{
      plan.timePlan.steps[0].id: true,
    },
    stepAttachments: <String, List<ProjectAttachment>>{
      plan.timePlan.steps[0].id: <ProjectAttachment>[
        ProjectAttachment(
          fileName: 'guide_rna_design.pdf',
          sizeBytes: 311_402,
          addedAt: now.subtract(const Duration(days: 3)),
        ),
      ],
    },
  );
}

Project _buildProteinFoldingProject(DateTime now) {
  final ExperimentPlan plan = _buildPlanC();
  return Project(
    id: 'project_protein_folding',
    title: 'Protein folding fluorescence assay',
    assignedScientistName: 'Tomás Pérez',
    assignedScientistAvatarUrl: 'https://i.pravatar.cc/120?u=tomas-perez',
    labName: 'Northwind Sciences',
    startedAt: now.subtract(const Duration(days: 42)),
    lastUpdatedAt: now.subtract(const Duration(hours: 4)),
    plan: plan,
    stepCompletion: <String, bool>{
      plan.timePlan.steps[0].id: true,
      plan.timePlan.steps[1].id: true,
      plan.timePlan.steps[2].id: true,
      plan.timePlan.steps[3].id: true,
    },
    stepAttachments: <String, List<ProjectAttachment>>{
      plan.timePlan.steps[1].id: <ProjectAttachment>[
        ProjectAttachment(
          fileName: 'reagent_lot_records.pdf',
          sizeBytes: 224_311,
          addedAt: now.subtract(const Duration(days: 30)),
        ),
      ],
      plan.timePlan.steps[3].id: <ProjectAttachment>[
        ProjectAttachment(
          fileName: 'fluorescence_curves.csv',
          sizeBytes: 2_104_220,
          addedAt: now.subtract(const Duration(days: 6)),
        ),
      ],
    },
  );
}

ExperimentPlan _buildPlanA() {
  return ExperimentPlan(
    description:
        'Five freeze-thaw cycles applied to encapsulated mRNA, with potency '
        'and integrity readouts at each cycle to characterise stability '
        'under realistic cold-chain stress.',
    budget: Budget(
      total: 7480.0,
      materials: <Material>[
        Material(
          id: generateLocalId('mat'),
          title: 'Lipid Nanoparticle Kit',
          catalogNumber: 'LNP-220',
          description: 'Pre-formulated LNP carrier reagents.',
          amount: 2,
          price: 1850.0,
        ),
        Material(
          id: generateLocalId('mat'),
          title: 'mRNA Reference Standard',
          catalogNumber: 'MRN-051',
          description: 'Quantified reference for potency calibration.',
          amount: 1,
          price: 920.0,
        ),
        Material(
          id: generateLocalId('mat'),
          title: 'Cold-Chain Logger',
          catalogNumber: 'CCL-09',
          description: 'Continuous temperature recorder.',
          amount: 4,
          price: 210.0,
        ),
      ],
    ),
    timePlan: TimePlan(
      totalDuration: const Duration(days: 18),
      steps: <Step>[
        Step(
          id: generateLocalId('step'),
          number: 1,
          duration: const Duration(days: 2),
          name: 'Confirm freeze-thaw windows',
          description:
              'Align cycle counts and dwell times with sponsor requirements.',
          milestone: 'Protocol approved',
        ),
        Step(
          id: generateLocalId('step'),
          number: 2,
          duration: const Duration(days: 3),
          name: 'Procure LNP reagents',
          description: 'Order reagents and validate cold-chain delivery.',
        ),
        Step(
          id: generateLocalId('step'),
          number: 3,
          duration: const Duration(days: 5),
          name: 'Run pilot cycle',
          description: 'Execute first cycle, record potency baseline.',
          milestone: 'Pilot data collected',
        ),
        Step(
          id: generateLocalId('step'),
          number: 4,
          duration: const Duration(days: 5),
          name: 'Repeat full cycle series',
          description: 'Run remaining cycles with integrity sampling.',
        ),
        Step(
          id: generateLocalId('step'),
          number: 5,
          duration: const Duration(days: 3),
          name: 'Compile stability report',
          description: 'Summarise potency curves and recommended limits.',
          milestone: 'Report delivered',
        ),
      ],
    ),
  );
}

ExperimentPlan _buildPlanB() {
  return ExperimentPlan(
    description:
        'Optimisation of CRISPR Cas9 delivery efficiency in primary '
        'hepatocyte cultures, comparing lipid and electroporation routes.',
    budget: Budget(
      total: 6320.0,
      materials: <Material>[
        Material(
          id: generateLocalId('mat'),
          title: 'Cas9 RNP Complex',
          catalogNumber: 'CAS-RNP-12',
          description: 'High-fidelity Cas9 ribonucleoprotein.',
          amount: 3,
          price: 940.0,
        ),
        Material(
          id: generateLocalId('mat'),
          title: 'Primary Hepatocyte Lot',
          catalogNumber: 'PHL-7',
          description: 'Cryopreserved donor lot.',
          amount: 1,
          price: 2100.0,
        ),
      ],
    ),
    timePlan: TimePlan(
      totalDuration: const Duration(days: 14),
      steps: <Step>[
        Step(
          id: generateLocalId('step'),
          number: 1,
          duration: const Duration(days: 2),
          name: 'Design guide RNAs',
          description: 'Select target sites and verify off-target risk.',
          milestone: 'Guides locked',
        ),
        Step(
          id: generateLocalId('step'),
          number: 2,
          duration: const Duration(days: 3),
          name: 'Procure cells and reagents',
          description: 'Coordinate cell lot delivery and reagent storage.',
        ),
        Step(
          id: generateLocalId('step'),
          number: 3,
          duration: const Duration(days: 4),
          name: 'Run delivery comparison',
          description: 'Run lipid vs. electroporation in triplicate.',
          milestone: 'Comparison complete',
        ),
        Step(
          id: generateLocalId('step'),
          number: 4,
          duration: const Duration(days: 3),
          name: 'Quantify edit efficiency',
          description: 'Sequence amplicons and tally edited reads.',
        ),
        Step(
          id: generateLocalId('step'),
          number: 5,
          duration: const Duration(days: 2),
          name: 'Deliver write-up',
          description: 'Compile recommended delivery protocol.',
          milestone: 'Report delivered',
        ),
      ],
    ),
  );
}

ExperimentPlan _buildPlanC() {
  return ExperimentPlan(
    description:
        'Fluorescence-based folding assay to characterise a candidate '
        'enzyme variant across temperature and pH gradients.',
    budget: Budget(
      total: 4980.0,
      materials: <Material>[
        Material(
          id: generateLocalId('mat'),
          title: 'Recombinant Enzyme',
          catalogNumber: 'RE-2204',
          description: 'Purified candidate variant.',
          amount: 2,
          price: 1050.0,
        ),
        Material(
          id: generateLocalId('mat'),
          title: 'Fluorescent Probe Set',
          catalogNumber: 'FPS-13',
          description: 'Five-channel folding probes.',
          amount: 1,
          price: 880.0,
        ),
      ],
    ),
    timePlan: TimePlan(
      totalDuration: const Duration(days: 12),
      steps: <Step>[
        Step(
          id: generateLocalId('step'),
          number: 1,
          duration: const Duration(days: 2),
          name: 'Lock assay conditions',
          description: 'Confirm temperature/pH grid with sponsor.',
          milestone: 'Conditions approved',
        ),
        Step(
          id: generateLocalId('step'),
          number: 2,
          duration: const Duration(days: 2),
          name: 'Procure probes',
          description: 'Order fluorescent probe set and verify lots.',
        ),
        Step(
          id: generateLocalId('step'),
          number: 3,
          duration: const Duration(days: 3),
          name: 'Calibrate plate reader',
          description: 'Run baseline curves on reference standards.',
          milestone: 'Reader calibrated',
        ),
        Step(
          id: generateLocalId('step'),
          number: 4,
          duration: const Duration(days: 3),
          name: 'Run gradient sweeps',
          description: 'Collect folding curves across the full grid.',
        ),
        Step(
          id: generateLocalId('step'),
          number: 5,
          duration: const Duration(days: 2),
          name: 'Deliver final report',
          description: 'Summarise folding stability envelope.',
          milestone: 'Report delivered',
        ),
      ],
    ),
  );
}
