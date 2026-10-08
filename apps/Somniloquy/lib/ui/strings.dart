import '../controllers/app_controller.dart';
import '../domain/models.dart';

class AppStrings {
  AppStrings(this.localeCode);

  final String localeCode;
  bool get isEnglish => localeCode == 'en';

  static const _zh = <String, String>{
    'appName': 'Somniloquy',
    'tonight': '今晚',
    'archive': '夜间卡片',
    'settings': '设置',
    'tonightTitle': '留一张夜间纸页',
    'tonightSubtitle': '只找出声音变化的位置，由你决定它意味着什么。',
    'promptLabel': '醒来时想记住什么？（可选）',
    'promptHint': '例如：记下醒来前最后一个画面',
    'contextTitle': '当晚背景（可多选）',
    'prepare': '准备录音',
    'localOnly': '不主动上传；音频与笔记写入应用沙盒',
    'notMedical': '不分析睡眠阶段，也不提供医疗判断',
    'consentTitle': '开始前确认',
    'consentBody':
        'Somniloquy 会持续使用麦克风，最长 12 小时，并用明显的录音状态提示你。请把设备放在稳定、通风的床头表面，不要放在枕头或床垫下。声音写入应用沙盒。本工具只标出音量变化，不能识别疾病、睡眠阶段或呼吸暂停。',
    'roomConsent': '我确认已获得同室人员所需的录音同意。',
    'cancel': '取消',
    'start': '开始录音',
    'recording': '正在录音',
    'calibrating': '正在建立房间声音基线',
    'listening': '正在寻找相对基线的声音变化',
    'momentsFound': '候选声音时刻',
    'amplitude': '当前音量',
    'stop': '停止并进入晨间核对',
    'stopTitle': '结束今晚的录音？',
    'stopBody': '停止后会保留本地音频，并进入人工核对。',
    'keepRecording': '继续录音',
    'confirmStop': '结束录音',
    'reviewTitle': '晨间核对',
    'reviewSubtitle': '候选只表示音量发生变化。请亲自试听后标注。',
    'morningNote': '醒来后的梦境或线索',
    'morningHint': '写下仍记得的画面、句子或感觉…',
    'noMoments': '没有发现超过环境基线的声音时刻。你仍可以保存晨间笔记。',
    'labeledByYou': '由你标注',
    'play': '播放前后约 12 秒',
    'saveCard': '保存夜间卡片',
    'reviewLater': '稍后核对',
    'reviewExitTitle': '暂时离开晨间核对？',
    'reviewExitBody': '尚未保存的标签和笔记不会写入。你可以保留原始录音草稿稍后继续，或永久删除它。',
    'keepDraft': '保留草稿',
    'deleteDraft': '永久删除草稿',
    'continueReview': '继续核对',
    'pendingReview': '待晨间核对',
    'pendingReviewBody': '录音已保存在本地；点按卡片继续标注。',
    'reviewRequired': '请先标注或忽略每一个候选声音时刻。',
    'saving': '正在保存…',
    'archiveTitle': '你的夜间纸页',
    'archiveSubtitle': '这里只呈现你亲自确认过的内容，不生成睡眠分数。',
    'backgroundPatterns': '已核对卡片中的当晚背景',
    'emptyArchive': '还没有夜间卡片',
    'emptyArchiveBody': '完成一次本地录音和晨间核对后，它会出现在这里。',
    'nightDetail': '夜间卡片',
    'prompt': '睡前提示',
    'note': '晨间回忆',
    'confirmedMoments': '已核对声音时刻',
    'noNote': '未填写晨间回忆',
    'deleteNight': '永久删除这张卡片',
    'deleteTitle': '永久删除？',
    'deleteBody': '这会移除夜间卡片和应用管理的原始音频，无法撤销。',
    'delete': '永久删除',
    'privacyTitle': '隐私与边界',
    'privacyBody':
        '无账号、无自有后台、无广告或分析 SDK。录音、声音时刻、标签和笔记写入应用沙盒，应用不会主动上传。若你启用系统设备备份，这些本地数据可能随设备备份保存。',
    'medicalTitle': '不是医疗工具',
    'medicalBody': 'Somniloquy 不检测鼾症、呼吸暂停、睡眠阶段或睡眠质量。如你担心健康问题，请咨询合格的医疗专业人士。',
    'language': '界面语言',
    'chinese': '简体中文',
    'english': 'English',
    'dataTitle': '本地数据',
    'clearAll': '永久删除全部数据',
    'clearAllTitle': '删除全部本地数据？',
    'clearAllBody': '所有夜间卡片和应用管理的音频都会被永久移除，无法撤销。',
    'interruptedTitle': '发现未完成的录音',
    'interruptedBody': '上次录音没有正常完成。为避免把未知状态当成完整记录，请确认并清理部分文件后再开始。',
    'discardInterrupted': '清理未完成录音',
    'retry': '重试',
    'loadFailedTitle': '无法读取本地数据',
    'loadFailedBody': '为防止覆盖已有记录，当前已锁定新建与写入。请重试读取。',
    'permissionHelp': '麦克风权限未开启。请前往系统设置 > Somniloquy > 麦克风后重试；历史和设置仍可使用。',
    'errorRecording': '无法开始录音。请检查麦克风、可用空间后重试。',
    'errorStop': '录音尚未安全结束，请保持应用打开并重试。',
    'errorSave': '保存失败，当前内容仍保留在页面中，请重试。',
    'errorDelete': '删除未完成，请重试并确认文件已清理。',
    'errorPlayback': '无法播放此声音时刻；本地音频可能缺失或不可用。',
    'dismiss': '知道了',
    'events': '个时刻',
    'duration': '录音时长',
    'background': '当晚背景',
    'recordingIndicator': '录音状态指示',
  };

  static const _en = <String, String>{
    'appName': 'Somniloquy',
    'tonight': 'Tonight',
    'archive': 'Night cards',
    'settings': 'Settings',
    'tonightTitle': 'Leave a page for the night',
    'tonightSubtitle':
        'We find changes in sound. Only you decide what they mean.',
    'promptLabel': 'What would you like to remember? (optional)',
    'promptHint': 'For example: remember the last image before waking',
    'contextTitle': 'Tonight’s context (choose any)',
    'prepare': 'Prepare to record',
    'localOnly':
        'No active upload; audio and notes are stored in the app sandbox',
    'notMedical': 'No sleep staging or medical conclusions',
    'consentTitle': 'Before you start',
    'consentBody':
        'Somniloquy will use the microphone continuously for up to 12 hours and will keep a clear recording indicator visible. Place the device on a stable, ventilated bedside surface—not under a pillow or mattress. Sound is written to the app sandbox. The app only marks changes in volume and cannot detect disease, sleep stages, or breathing pauses.',
    'roomConsent':
        'I confirm I have the consent required to record anyone sharing the room.',
    'cancel': 'Cancel',
    'start': 'Start recording',
    'recording': 'Recording',
    'calibrating': 'Learning the room’s sound baseline',
    'listening': 'Finding sound changes above the baseline',
    'momentsFound': 'Candidate sound moments',
    'amplitude': 'Current level',
    'stop': 'Stop and review in the morning',
    'stopTitle': 'End tonight’s recording?',
    'stopBody': 'Stopping keeps the audio locally and opens manual review.',
    'keepRecording': 'Keep recording',
    'confirmStop': 'End recording',
    'reviewTitle': 'Morning review',
    'reviewSubtitle':
        'Candidates only mean the volume changed. Listen and label them yourself.',
    'morningNote': 'Dream or memory after waking',
    'morningHint': 'Write any image, phrase, or feeling you still remember…',
    'noMoments':
        'No sound rose above the room baseline. You can still save a morning note.',
    'labeledByYou': 'Labeled by you',
    'play': 'Play about 12 seconds of context',
    'saveCard': 'Save night card',
    'reviewLater': 'Review later',
    'reviewExitTitle': 'Leave morning review for now?',
    'reviewExitBody':
        'Unsaved labels and notes will not be written. Keep the original recording draft to continue later, or delete it permanently.',
    'keepDraft': 'Keep draft',
    'deleteDraft': 'Delete draft permanently',
    'continueReview': 'Continue review',
    'pendingReview': 'Morning review pending',
    'pendingReviewBody':
        'The recording is saved locally. Tap the card to continue labeling.',
    'reviewRequired':
        'Label or ignore every candidate sound moment before saving.',
    'saving': 'Saving…',
    'archiveTitle': 'Your night pages',
    'archiveSubtitle':
        'Only content you reviewed appears here. There is no sleep score.',
    'backgroundPatterns': 'Night context in reviewed cards',
    'emptyArchive': 'No night cards yet',
    'emptyArchiveBody':
        'Complete a local recording and morning review to create one.',
    'nightDetail': 'Night card',
    'prompt': 'Bedtime prompt',
    'note': 'Morning memory',
    'confirmedMoments': 'Reviewed sound moments',
    'noNote': 'No morning memory was added',
    'deleteNight': 'Permanently delete this card',
    'deleteTitle': 'Delete permanently?',
    'deleteBody':
        'This removes the night card and the original audio managed by the app. It cannot be undone.',
    'delete': 'Delete permanently',
    'privacyTitle': 'Privacy and boundaries',
    'privacyBody':
        'No account, backend, ads, or analytics SDK. Recordings, sound moments, labels, and notes are stored in the app sandbox and are not actively uploaded by the app. If device backup is enabled, this local data may be included in that system backup.',
    'medicalTitle': 'Not a medical tool',
    'medicalBody':
        'Somniloquy does not detect snoring disorders, apnea, sleep stages, or sleep quality. Speak with a qualified health professional about health concerns.',
    'language': 'App language',
    'chinese': '简体中文',
    'english': 'English',
    'dataTitle': 'Local data',
    'clearAll': 'Permanently delete all data',
    'clearAllTitle': 'Delete all local data?',
    'clearAllBody':
        'Every night card and app-managed audio file will be permanently removed. This cannot be undone.',
    'interruptedTitle': 'Unfinished recording found',
    'interruptedBody':
        'The last recording did not finish normally. To avoid treating an unknown state as complete, review and remove the partial file before starting again.',
    'discardInterrupted': 'Remove unfinished recording',
    'retry': 'Retry',
    'loadFailedTitle': 'Local data could not be read',
    'loadFailedBody':
        'Creating and writing are locked to avoid overwriting existing records. Retry loading your data.',
    'permissionHelp':
        'Microphone access is off. Open system Settings > Somniloquy > Microphone, then retry. Night cards and Settings still work.',
    'errorRecording':
        'Recording could not start. Check the microphone and available storage, then retry.',
    'errorStop':
        'The recording has not ended safely. Keep the app open and retry.',
    'errorSave':
        'Saving failed. Your current edits remain on screen; please retry.',
    'errorDelete':
        'Deletion did not finish. Retry and verify that the file is gone.',
    'errorPlayback':
        'This moment cannot be played. Its local audio may be missing or unavailable.',
    'dismiss': 'Got it',
    'events': 'moments',
    'duration': 'Recording length',
    'background': 'Night context',
    'recordingIndicator': 'Recording indicator',
  };

  String t(String key) => (isEnglish ? _en : _zh)[key] ?? key;

  String errorText(ControllerError error) => switch (error) {
    ControllerError.load => t('loadFailedBody'),
    ControllerError.permission => t('permissionHelp'),
    ControllerError.recording => t('errorRecording'),
    ControllerError.stop => t('errorStop'),
    ControllerError.save => t('errorSave'),
    ControllerError.delete => t('errorDelete'),
    ControllerError.playback => t('errorPlayback'),
    ControllerError.reviewRequired => t('reviewRequired'),
  };

  String contextName(String key) => switch ((key, isEnglish)) {
    ('lateMeal', false) => '较晚进食',
    ('lateMeal', true) => 'Late meal',
    ('stressfulDay', false) => '紧张的一天',
    ('stressfulDay', true) => 'Stressful day',
    ('caffeine', false) => '晚间咖啡因',
    ('caffeine', true) => 'Evening caffeine',
    ('travel', false) => '旅行或陌生房间',
    ('travel', true) => 'Travel or new room',
    ('sharedRoom', false) => '与他人同室',
    ('sharedRoom', true) => 'Shared room',
    _ => key,
  };

  String labelName(MomentLabel label) => switch ((label, isEnglish)) {
    (MomentLabel.pending, false) => '尚未标注',
    (MomentLabel.pending, true) => 'Not labeled yet',
    (MomentLabel.possibleSpeech, false) => '我听到：可能的说话声',
    (MomentLabel.possibleSpeech, true) => 'I heard: possible speech',
    (MomentLabel.breathing, false) => '我听到：呼吸声音',
    (MomentLabel.breathing, true) => 'I heard: breathing sound',
    (MomentLabel.environment, false) => '我听到：环境声音',
    (MomentLabel.environment, true) => 'I heard: room sound',
    (MomentLabel.uncertain, false) => '我听到：不确定',
    (MomentLabel.uncertain, true) => 'I heard: unsure',
    (MomentLabel.ignored, false) => '忽略这个时刻',
    (MomentLabel.ignored, true) => 'Ignore this moment',
  };

  String formatDuration(Duration value) {
    final hours = value.inHours;
    final minutes = value.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
    return hours > 0
        ? '$hours:$minutes:$seconds'
        : '${value.inMinutes}:$seconds';
  }

  String formatDate(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return isEnglish
        ? '${value.year}-$month-$day · $hour:$minute'
        : '${value.year}年$month月$day日 · $hour:$minute';
  }

  String momentTime(int seconds) => formatDuration(Duration(seconds: seconds));
}
