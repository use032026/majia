import '../domain/models.dart';

const bundledLessonCount = 8;
const maximumLessonCount = 56;
const maximumRemoteLessonCount = maximumLessonCount - bundledLessonCount;

const lessons = <Lesson>[
  Lesson(
    id: 'axis-baseline',
    kind: LessonKind.axis,
    mode: ExperimentMode.axisBaseline,
    title: LocalizedText(zh: '被截断的起点', en: 'The cropped baseline'),
    subtitle: LocalizedText(zh: '坐标轴 · 1', en: 'Axes · 1'),
    claim: LocalizedText(
      zh: '方案 B 的表现远高于方案 A',
      en: 'Plan B performs far better than Plan A',
    ),
    prompt: LocalizedText(
      zh: '这张柱状图公平支持这个论断吗？',
      en: 'Does this bar chart fairly support the claim?',
    ),
    correctVerdict: Verdict.misleading,
    explanation: LocalizedText(
      zh: '数值只从 96 变到 99，但在 0–100 的完整尺度上只占 3%，改用 95–100 的绘图区间会把可见差异放大 20.0 倍。非零起点并非永远错误；问题在于它是否被清楚标示，以及论断是否与真实差异相称。',
      en: 'The values move only from 96 to 99: a 3% gap on the full 0–100 scale. Plotting only 95–100 makes that visible gap 20.0 times larger. A non-zero baseline is not always wrong; it must be explicit and the claim must match the real change.',
    ),
    checklist: [
      LocalizedText(
        zh: '检查轴起点与断轴标记',
        en: 'Check the baseline and any axis break',
      ),
      LocalizedText(
        zh: '同时读取数值与视觉高度',
        en: 'Read the values as well as visual height',
      ),
    ],
    misconception: LocalizedText(
      zh: '被柱形高度代替了数值判断',
      en: 'Let bar height replace value reading',
    ),
    values: [96, 99],
    initialParameter: 95,
    fairParameter: 0,
    minParameter: 0,
    maxParameter: 95,
    axisMaximum: 100,
  ),
  Lesson(
    id: 'axis-context',
    kind: LessonKind.axis,
    mode: ExperimentMode.axisPrecision,
    title: LocalizedText(zh: '需要细看，不等于欺骗', en: 'Zoomed does not mean false'),
    subtitle: LocalizedText(zh: '坐标轴 · 2', en: 'Axes · 2'),
    claim: LocalizedText(
      zh: '仪器读数出现了可检测的小幅偏移',
      en: 'The instrument shows a detectable small shift',
    ),
    prompt: LocalizedText(
      zh: '标明 70–82 的精密测量图一定误导吗？',
      en: 'Is a clearly labeled 70–82 measurement plot always misleading?',
    ),
    correctVerdict: Verdict.fair,
    explanation: LocalizedText(
      zh: '精密测量图可以放大窄范围，只要范围与单位醒目、数据点没有被夸成巨大的现实影响，且读者能看到完整语境。判断应看用途与标注，而不是机械要求所有轴从零开始。',
      en: 'A precision plot may zoom into a narrow range when the range and units are prominent, the claim does not inflate the practical effect, and context remains visible. Judge purpose and labeling, not a zero-only rule.',
    ),
    checklist: [
      LocalizedText(
        zh: '图表类型是否要求从零比较面积',
        en: 'Does the chart encode magnitude by area?',
      ),
      LocalizedText(
        zh: '范围、单位和现实影响是否明确',
        en: 'Are range, units, and practical impact explicit?',
      ),
    ],
    misconception: LocalizedText(
      zh: '把非零起点一概判错',
      en: 'Treat every non-zero baseline as wrong',
    ),
    values: [74, 78],
    initialParameter: 70,
    fairParameter: 0,
    minParameter: 0,
    maxParameter: 72,
    axisMaximum: 82,
  ),
  Lesson(
    id: 'correlation-outlier',
    kind: LessonKind.correlation,
    mode: ExperimentMode.correlationOutlier,
    title: LocalizedText(zh: '一个点改变故事', en: 'One point changes the story'),
    subtitle: LocalizedText(zh: '相关性 · 1', en: 'Correlation · 1'),
    claim: LocalizedText(
      zh: '两个指标稳定地一起增长',
      en: 'The two measures rise together consistently',
    ),
    prompt: LocalizedText(
      zh: '当前相关系数足以支持“稳定”吗？',
      en: 'Is the current correlation enough to claim consistency?',
    ),
    correctVerdict: Verdict.needsContext,
    explanation: LocalizedText(
      zh: '加入一个高杠杆点后，相关系数会显著改变。单个汇总数隐藏了样本量、异常点和分组结构；先看散点，再说明敏感性。',
      en: 'A single high-leverage point changes the coefficient sharply. One summary number hides sample size, outliers, and subgroups; inspect the points and report sensitivity.',
    ),
    checklist: [
      LocalizedText(
        zh: '比较包含与排除异常点的结果',
        en: 'Compare results with and without the outlier',
      ),
      LocalizedText(
        zh: '不要只报告一个相关系数',
        en: 'Do not report the coefficient alone',
      ),
    ],
    misconception: LocalizedText(
      zh: '只看相关系数，忽略散点结构',
      en: 'Read only r and ignore the point pattern',
    ),
    values: [1, 1, 2, 2.2, 3, 3.1, 4, 4.2, 5, 4.8, 9, 1.2],
    initialParameter: 1,
    fairParameter: 0,
    minParameter: 0,
    maxParameter: 1,
  ),
  Lesson(
    id: 'correlation-cause',
    kind: LessonKind.correlation,
    mode: ExperimentMode.correlationCausation,
    title: LocalizedText(zh: '一起变化，不等于因果', en: 'Together is not causal'),
    subtitle: LocalizedText(zh: '相关性 · 2', en: 'Correlation · 2'),
    claim: LocalizedText(
      zh: '冷饮销量导致了游泳事故增加',
      en: 'Ice-cream sales cause more swimming incidents',
    ),
    prompt: LocalizedText(
      zh: '强相关能证明这个因果论断吗？',
      en: 'Can a strong correlation prove this causal claim?',
    ),
    correctVerdict: Verdict.needsContext,
    explanation: LocalizedText(
      zh: '温度可能同时推动冷饮销量和游泳人数。相关性描述共变，但因果需要时间顺序、机制、混杂因素和更合适的研究设计。',
      en: 'Temperature can raise both ice-cream sales and the number of swimmers. Correlation describes co-movement; causation also needs timing, mechanism, confounders, and a suitable study design.',
    ),
    checklist: [
      LocalizedText(
        zh: '寻找同时影响两者的第三变量',
        en: 'Look for a third variable affecting both',
      ),
      LocalizedText(
        zh: '区分预测关系与因果机制',
        en: 'Separate prediction from causal mechanism',
      ),
    ],
    misconception: LocalizedText(
      zh: '把强相关直接解释为因果',
      en: 'Turn strong correlation directly into causation',
    ),
    values: [1, 1.2, 2, 2.1, 3, 3.2, 4, 4.4, 5, 5.1, 7, 7.4],
    initialParameter: 0,
    fairParameter: 1,
    minParameter: 0,
    maxParameter: 1,
  ),
  Lesson(
    id: 'sample-fans',
    kind: LessonKind.sample,
    mode: ExperimentMode.sampleComposition,
    title: LocalizedText(zh: '只问最活跃的人', en: 'Only ask the fans'),
    subtitle: LocalizedText(zh: '样本 · 1', en: 'Sampling · 1'),
    claim: LocalizedText(
      zh: '九成用户每天都离不开这个功能',
      en: 'Nine in ten users depend on this feature daily',
    ),
    prompt: LocalizedText(
      zh: '只在重度用户群发布问卷，结论可靠吗？',
      en: 'Is a poll posted only to power users reliable?',
    ),
    correctVerdict: Verdict.misleading,
    explanation: LocalizedText(
      zh: '重度用户的日用率是 90%，普通用户只有 30%。当样本几乎全来自重度用户时，样本估计不能代表总体。拖动覆盖比例查看结论如何变化。',
      en: 'Daily use is 90% among power users and 30% among regular users. A sample dominated by power users cannot represent everyone. Change coverage to see the estimate move.',
    ),
    checklist: [
      LocalizedText(
        zh: '谁有机会进入样本？',
        en: 'Who had a chance to enter the sample?',
      ),
      LocalizedText(
        zh: '样本构成是否匹配目标总体？',
        en: 'Does sample composition match the target population?',
      ),
    ],
    misconception: LocalizedText(
      zh: '把方便取得的样本当成总体',
      en: 'Treat a convenient sample as the population',
    ),
    values: [0.9, 0.3],
    initialParameter: 0.95,
    fairParameter: 0.2,
    minParameter: 0.05,
    maxParameter: 0.95,
  ),
  Lesson(
    id: 'sample-strata',
    kind: LessonKind.sample,
    mode: ExperimentMode.sampleStrata,
    title: LocalizedText(zh: '样本小，也可以有结构', en: 'Small can still be structured'),
    subtitle: LocalizedText(zh: '样本 · 2', en: 'Sampling · 2'),
    claim: LocalizedText(
      zh: '分层样本估计约六成参与者赞同',
      en: 'A stratified sample estimates about 60% support',
    ),
    prompt: LocalizedText(
      zh: '按总体比例抽取两组后，这个表述公平吗？',
      en: 'After proportional sampling of two groups, is the statement fair?',
    ),
    correctVerdict: Verdict.fair,
    explanation: LocalizedText(
      zh: '代表性不只由样本大小决定。若抽样框、组内随机过程和响应偏差都被说明，按总体比例分层可以比更大的便利样本更可靠。',
      en: 'Representativeness is not sample size alone. With a clear frame, random selection within groups, and response bias addressed, proportional strata can beat a larger convenience sample.',
    ),
    checklist: [
      LocalizedText(
        zh: '核对总体比例与组内抽样方式',
        en: 'Check population proportions and within-group sampling',
      ),
      LocalizedText(
        zh: '报告不确定性和未响应',
        en: 'Report uncertainty and non-response',
      ),
    ],
    misconception: LocalizedText(
      zh: '只按样本数量判断代表性',
      en: 'Judge representativeness by size alone',
    ),
    values: [0.7, 0.5],
    initialParameter: 0.5,
    fairParameter: 0.5,
    minParameter: 0.1,
    maxParameter: 0.9,
  ),
  Lesson(
    id: 'risk-relative',
    kind: LessonKind.risk,
    mode: ExperimentMode.riskRelative,
    title: LocalizedText(zh: '“降低一半”的另一面', en: 'The other half of “50% less”'),
    subtitle: LocalizedText(zh: '风险表达 · 1', en: 'Risk framing · 1'),
    claim: LocalizedText(
      zh: '干预让风险降低 50%，效果巨大',
      en: 'The intervention cuts risk by 50%, a huge effect',
    ),
    prompt: LocalizedText(
      zh: '只有相对降幅，这个论断够完整吗？',
      en: 'Is the relative reduction alone enough?',
    ),
    correctVerdict: Verdict.needsContext,
    explanation: LocalizedText(
      zh: '从 2/100 降到 1/100 的相对降幅确实是 50%，绝对变化却是每 100 人减少 1 人。两种表达都应出现，读者还需要副作用、时间范围和不确定性。',
      en: 'A drop from 2 in 100 to 1 in 100 is a 50% relative reduction, but only 1 fewer person per 100 in absolute terms. Show both, plus harms, timeframe, and uncertainty.',
    ),
    checklist: [
      LocalizedText(
        zh: '同时给出基线与绝对变化',
        en: 'Show baseline and absolute change together',
      ),
      LocalizedText(
        zh: '补充时间范围、副作用与不确定性',
        en: 'Add timeframe, harms, and uncertainty',
      ),
    ],
    misconception: LocalizedText(
      zh: '只看相对变化，忽略基线',
      en: 'Read relative change without its baseline',
    ),
    values: [0.02, 0.01],
    initialParameter: 0,
    fairParameter: 2,
    minParameter: 0,
    maxParameter: 2,
  ),
  Lesson(
    id: 'risk-frequency',
    kind: LessonKind.risk,
    mode: ExperimentMode.riskFrequency,
    title: LocalizedText(zh: '三种写法，同一个概率', en: 'Three forms, one probability'),
    subtitle: LocalizedText(zh: '风险表达 · 2', en: 'Risk framing · 2'),
    claim: LocalizedText(
      zh: '5%、5/100 和约 1/20 表达同一概率',
      en: '5%, 5 in 100, and about 1 in 20 express the same chance',
    ),
    prompt: LocalizedText(
      zh: '在分母和时间范围一致时，这个表述公平吗？',
      en: 'With the same denominator and timeframe, is this fair?',
    ),
    correctVerdict: Verdict.fair,
    explanation: LocalizedText(
      zh: '三种写法在这里数值等价。自然频率常更直观，但任何格式都必须保持相同分母、时间范围和人群，不能混用来放大情绪。',
      en: 'The three forms are numerically equivalent here. Natural frequencies can be easier to read, but denominator, timeframe, and population must stay aligned.',
    ),
    checklist: [
      LocalizedText(
        zh: '换算时保持分母一致',
        en: 'Keep denominators aligned when converting',
      ),
      LocalizedText(
        zh: '核对时间范围和目标人群',
        en: 'Check timeframe and target population',
      ),
    ],
    misconception: LocalizedText(
      zh: '把表达格式变化误认为概率变化',
      en: 'Mistake a format change for a probability change',
    ),
    values: [0.05, 0.05],
    initialParameter: 0,
    fairParameter: 2,
    minParameter: 0,
    maxParameter: 2,
  ),
];

Lesson? lessonById(String id, [Iterable<Lesson> catalog = lessons]) {
  for (final lesson in catalog) {
    if (lesson.id == id) return lesson;
  }
  return null;
}
