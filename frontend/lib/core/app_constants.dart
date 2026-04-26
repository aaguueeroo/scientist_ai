const double kSpace4 = 4;
const double kSpace8 = 8;
const double kSpace12 = 12;
const double kSpace16 = 16;
const double kSpace24 = 24;
const double kSpace32 = 32;
const double kSpace40 = 40;

const double kRadius = 8;

/// Horizontal Marie Query wordmark at the top of the shell sidebar.
const String kSidebarLogoAsset = 'lib/assets/logo.png';
const double kSidebarLogoHeight = 100;

/// Cold-start launch screen: subtitle below the wordmark.
const String kAppLaunchSubtitle = 'Your AI lab assistant';

/// Max width of the wordmark on the launch screen.
const double kAppLaunchLogoMaxWidth = 320;

/// Vertical gap between logo and subtitle on the launch screen.
const double kAppLaunchLogoSubtitleSpacing = kSpace24;

/// Minimum time the launch screen stays visible so entry motion can read.
const Duration kAppLaunchMinVisibleDuration = Duration(milliseconds: 1400);

/// Fade-out of the whole launch layer before showing [ScientistApp].
const Duration kAppLaunchExitFadeDuration = Duration(milliseconds: 420);

/// Total duration of logo + subtitle entry choreography.
const Duration kAppLaunchEntryAnimationDuration = Duration(milliseconds: 1400);

/// One-time ease-out reveal of [AppShell] after cold start (low contrast, small motion).
const Duration kAppShellColdStartRevealDuration = Duration(milliseconds: 480);

/// [SlideTransition] Y fraction of the shell body (downward settle into place).
const double kAppShellColdStartRevealSlideFraction = 0.014;

/// Opacity at the start of the shell reveal (avoids an empty frame at t = 0).
const double kAppShellColdStartRevealOpacityBegin = 0.93;

/// Opacity at the end of the shell reveal.
const double kAppShellColdStartRevealOpacityEnd = 1.0;

const double kSidebarWidth = 260;
const double kSidebarMinWidth = 200;
const double kSidebarMaxWidth = 400;
const double kContentMaxWidth = 1200;
const double kHomeMaxWidth = 720;

/// Decorative Marie illustration on literature / plan workspace routes.
const double kMarieWorkspacePeekHeight = 150;

/// Max width for provider API key help tooltips (OpenAI / Tavily).
const double kProviderApiKeyHelpTooltipMaxWidth = 200;

const double kPlanHeroMetricValueSize = 52;
const double kPlanQcAlertIconSize = 36;
const double kPlanQcInlineIconSize = 20;
const double kPlanTimelineLineThickness = 2;
const double kPlanTimelineNodeDiameter = 12;
const double kPlanTimelineMilestoneSize = 20;
const double kPlanTimelineDagLabelBandHeight = 40;
const double kPlanTimelineDagLaneRowHeight = 44;
const double kPlanTimelineDagSubLabelBandHeight = 32;
const double kPlanTimelineDagMinNodeWidth = 56;

/// Min width of the materials list for the full 5-column table.
const double kPlanMaterialsLayoutFullMinWidth = 500;

/// Below [kPlanMaterialsLayoutFullMinWidth] but above this, use compact 3-column layout.
const double kPlanMaterialsLayoutCompactMinWidth = 260;

const double kBudgetIncrementLow = 10;
const double kBudgetIncrementHigh = 100;
const double kBudgetIncrementThreshold = 1000;

/// Plan material editor: [InlineEditableText] + stepper amount delta.
const int kMaterialAmountStep = 1;

/// Plan material editor: price stepper delta (dollars). Inline typing still
/// allows any decimal.
const double kMaterialPriceStep = 1;
