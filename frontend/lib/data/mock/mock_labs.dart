/// Partner lab shown when sending an experiment plan for execution (mock data).
class MockLab {
  const MockLab({
    required this.id,
    required this.name,
    required this.contactScientistName,
    required this.contactScientistAvatarUrl,
  });

  final String id;
  final String name;
  final String contactScientistName;
  final String contactScientistAvatarUrl;
}

/// Fixed list of labs the funder can assign a plan to in this preview.
List<MockLab> buildMockLabs() {
  return const <MockLab>[
    MockLab(
      id: 'lab_bioready',
      name: 'BioReady Labs',
      contactScientistName: 'Alex Chen',
      contactScientistAvatarUrl: 'https://i.pravatar.cc/120?u=alex-chen',
    ),
    MockLab(
      id: 'lab_helix',
      name: 'Helix CRO',
      contactScientistName: 'Maya Rivera',
      contactScientistAvatarUrl: 'https://i.pravatar.cc/120?u=maya-rivera',
    ),
    MockLab(
      id: 'lab_northwind',
      name: 'Northwind Sciences',
      contactScientistName: 'Tomás Pérez',
      contactScientistAvatarUrl: 'https://i.pravatar.cc/120?u=tomas-perez',
    ),
    MockLab(
      id: 'lab_vertex',
      name: 'Vertex Benchworks',
      contactScientistName: 'Sam Okonkwo',
      contactScientistAvatarUrl: 'https://i.pravatar.cc/120?u=sam-okonkwo',
    ),
  ];
}
