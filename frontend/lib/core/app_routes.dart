const String kRouteHome = '/';
const String kRoutePrompt = '/prompt';
const String kRouteLiterature = '/literature';
const String kRoutePlan = '/plan';
const String kRouteReviewer = '/reviewer';
const String kRoutePastConversation = '/past-conversation';
const String kRouteOpenAiApiKeys = '/api-keys';

/// [StatefulShellRoute] branch 0: workspace (home, literature, plan, …).
const int kBranchConversation = 0;

/// [StatefulShellRoute] branch 1: reviewer.
const int kBranchReviewer = 1;
