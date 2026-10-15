import '../../core/models/tab_bar_item.dart';

/// page-mine 默认卡片骨架（自上而下与 iOS `STNewMineViewController` / `mine_items.json` 一致）。
/// 后台下发 `page.cards` 后会覆盖；仅当 Tab 未带 cards 且无 page 接口数据时由 [ConfiguredMinePage] 注入。
List<ConfigCardItemData> kDefaultMinePageCards() {
  const transparent = '#00000000';

  Map<String, dynamic> listItemAuth() => {
        'title': '身份认证',
        'icon_asset': 'st_mine_real_auth',
        'router': '/mine/auth',
        'mine_subtitle_mode': 'auth',
      };

  Map<String, dynamic> listItemBank() => {
        'title': '银行卡',
        'icon_asset': 'st_mine_bank_card',
        'router': '/mine/bank',
        'mine_subtitle_mode': 'bank',
      };

  Map<String, dynamic> listItemWallet() => {
        'title': '电子钱包',
        'icon_asset': 'st_mine_wallet_black',
        'router': '/mine/ewallet?type=1',
        'mine_subtitle_mode': 'ewallet',
      };

  return [
    ConfigCardItemData(
      cardId: 'mine_header_4',
      cardStyle: 'header_4',
      bgColor: transparent,
      title: 'mine_header',
    ),
    ConfigCardItemData(
      cardId: 'mine_balance_1',
      cardStyle: 'balance_1',
      bgColor: transparent,
      cardDetail: {},
    ),
    ConfigCardItemData(
      cardId: 'mine_grid_1',
      cardStyle: 'grid_1',
      bgColor: transparent,
      cardDetail: {
        'num_per_line': 5,
        'items': [
          {
            'title': '存款',
            'icon_asset': 'st_mine_deposit_th',
            'router': '/mine/deposit',
          },
          {
            'title': '提现',
            'icon_asset': 'st_mine_draw_th',
            'router': '/mine/draw',
          },
          {
            'title': '持仓',
            'icon_asset': 'st_mine_position',
            'router': '/trade/accountprofile',
          },
          {
            'title': '任务中心',
            'icon_asset': 'st_mine_activity',
            'router': '/web',
            'link': '',
          },
          {
            'title': '资产',
            'icon_asset': 'st_mine_asset',
            'router': '/mine/wallet',
          },
        ],
      },
    ),
    ConfigCardItemData(
      cardId: 'mine_account_3',
      cardStyle: 'account_3',
      title: 'account',
      bgColor: transparent,
      cardDetail: {},
    ),
    ConfigCardItemData(
      cardId: 'mine_list_1',
      cardStyle: 'list_1',
      bgColor: '#FFFFFF',
      cardDetail: {
        'items': [
          listItemAuth(),
          listItemBank(),
          listItemWallet(),
        ],
      },
    ),
  ];
}
