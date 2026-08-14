/**
 * LucideIcon → HarmonyOS Symbol 图标组件
 *
 * 使用系统内置 SymbolGlyph 渲染，自适应系统主题。
 */

export class LucideIcons {
  static readonly MESSAGE_SQUARE: string = 'message'
  static readonly SETTINGS: string = 'gearshape'
  static readonly PLUS: string = 'plus'
  static readonly ARROW_LEFT: string = 'chevron_left'
  static readonly CHEVRON_RIGHT: string = 'chevron_right'
  static readonly CHEVRON_DOWN: string = 'chevron_down'
  static readonly CHEVRON_UP: string = 'chevron_up'
  static readonly X: string = 'xmark'
  static readonly TRASH: string = 'ohos_trash'
  static readonly SHARE: string = 'share'
  static readonly SQUARE_AND_PENCIL: string = 'square_and_pencil'
  static readonly PLUS_SQUARE: string = 'plus_square_on_square_fill'
  static readonly CHECK: string = 'checkmark'
  static readonly USER: string = 'person'
  static readonly SYNC: string = 'arrow_clockwise'
  static readonly CLOUD: string = 'cloud'
  static readonly BACKUP: string = 'square_grid_2x2'
  static readonly RENAME: string = 'rename'
  static readonly ELLIPSIS_CIRCLE: string = 'ellipsis_circle'
  static readonly DOT_GRID_2X2: string = 'dot_grid_2x2_square'
  static readonly ARROW_UP: string = 'arrow_up'
  static readonly ARROW_COUNTERCLOCKWISE: string = 'arrow_counterclockwise'
  static readonly CLEAN: string = 'trash_fill'
}

@Component
export struct LucideIcon {
  @Prop icon: string = 'message'
  @Prop color: string = '#333333'
  @Prop iconSize: number = 24

  build() {
    if (this.icon === 'message') {
      SymbolGlyph($r('sys.symbol.message'))
        .fontSize(this.iconSize)
        .fontColor([this.color])
    } else if (this.icon === 'gearshape') {
      SymbolGlyph($r('sys.symbol.gearshape'))
        .fontSize(this.iconSize)
        .fontColor([this.color])
    } else if (this.icon === 'plus') {
      SymbolGlyph($r('sys.symbol.plus'))
        .fontSize(this.iconSize)
        .fontColor([this.color])
    } else if (this.icon === 'chevron_left') {
      SymbolGlyph($r('sys.symbol.chevron_left'))
        .fontSize(this.iconSize)
        .fontColor([this.color])
    } else if (this.icon === 'chevron_right') {
      SymbolGlyph($r('sys.symbol.chevron_right'))
        .fontSize(this.iconSize)
        .fontColor([this.color])
    } else if (this.icon === 'chevron_down') {
      SymbolGlyph($r('sys.symbol.chevron_down'))
        .fontSize(this.iconSize)
        .fontColor([this.color])
    } else if (this.icon === 'chevron_up') {
      SymbolGlyph($r('sys.symbol.chevron_up'))
        .fontSize(this.iconSize)
        .fontColor([this.color])
    } else if (this.icon === 'xmark') {
      SymbolGlyph($r('sys.symbol.xmark'))
        .fontSize(this.iconSize)
        .fontColor([this.color])
    } else if (this.icon === 'ohos_trash') {
      SymbolGlyph($r('sys.symbol.ohos_trash'))
        .fontSize(this.iconSize)
        .fontColor([this.color])
    } else if (this.icon === 'share') {
      SymbolGlyph($r('sys.symbol.share'))
        .fontSize(this.iconSize)
        .fontColor([this.color])
    } else if (this.icon === 'square_and_pencil') {
      SymbolGlyph($r('sys.symbol.square_and_pencil'))
        .fontSize(this.iconSize)
        .fontColor([this.color])
    } else if (this.icon === 'plus_square_on_square_fill') {
      SymbolGlyph($r('sys.symbol.plus_square_on_square_fill'))
        .fontSize(this.iconSize)
        .fontColor([this.color])
    } else if (this.icon === 'checkmark') {
      SymbolGlyph($r('sys.symbol.checkmark'))
        .fontSize(this.iconSize)
        .fontColor([this.color])
    } else if (this.icon === 'person') {
      SymbolGlyph($r('sys.symbol.person'))
        .fontSize(this.iconSize)
        .fontColor([this.color])
    } else if (this.icon === 'arrow_clockwise') {
      SymbolGlyph($r('sys.symbol.arrow_clockwise'))
        .fontSize(this.iconSize)
        .fontColor([this.color])
    } else if (this.icon === 'cloud') {
      SymbolGlyph($r('sys.symbol.cloud'))
        .fontSize(this.iconSize)
        .fontColor([this.color])
    } else if (this.icon === 'square_grid_2x2') {
      SymbolGlyph($r('sys.symbol.square_grid_2x2'))
        .fontSize(this.iconSize)
        .fontColor([this.color])
    } else if (this.icon === 'rename') {
      SymbolGlyph($r('sys.symbol.rename'))
        .fontSize(this.iconSize)
        .fontColor([this.color])
    } else if (this.icon === 'ellipsis_circle') {
      SymbolGlyph($r('sys.symbol.ellipsis_circle'))
        .fontSize(this.iconSize)
        .fontColor([this.color])
    } else if (this.icon === 'dot_grid_2x2_square') {
      SymbolGlyph($r('sys.symbol.dot_grid_2x2'))
        .fontSize(this.iconSize)
        .fontColor([this.color])
    } else if (this.icon === 'arrow_up') {
      SymbolGlyph($r('sys.symbol.arrowshape_up'))
        .fontSize(this.iconSize)
        .fontColor([this.color])
    } else if (this.icon === 'arrow_counterclockwise') {
      SymbolGlyph($r('sys.symbol.arrow_counterclockwise'))
        .fontSize(this.iconSize)
        .fontColor([this.color])
    } else if (this.icon === 'trash_fill') {
      SymbolGlyph($r('sys.symbol.trash_fill'))
        .fontSize(this.iconSize)
        .fontColor([this.color])
    }
  }
}
