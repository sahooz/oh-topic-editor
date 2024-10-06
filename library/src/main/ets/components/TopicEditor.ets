import { componentUtils } from '@kit.ArkUI'

@Component
export struct TopicEditor {
  controller: TopicEditorController = new TopicEditorController()
  /** 是否点两次删除才把TopicSpan删除 */
  @Prop doubleDelete: boolean = true
  /** 为了方便灵活地控制各种样式、设置选项，RichEditor通过BuilderParam传入，由调用者自行创建 */
  @BuilderParam richEditorBuilder: (controller: RichEditorController, aboutToDeleteCallback: Callback<RichEditorDeleteValue, boolean>) => void

  /** 删除监听 */
  private aboutToDeleteCallback = (val: RichEditorDeleteValue) => {
    // 处理双击删除，只有一个Span的时候才可能是删除TopicSpan
    if(this.doubleDelete && val.richEditorDeleteSpans.length == 1) {
      let span = val.richEditorDeleteSpans[0]
      let editorController = this.controller.getRichEditorController()
      let selection = editorController.getSelection()
      // 判断是否TopicSpan以及当前是否被选中，如果选中了直接删除，未选中则选中但不删除
      if(isTopicSpan(span) && !(selection.selection.length == 2 && selection.selection[0] == span.spanPosition.spanRange[0] && selection.selection[1] == span.spanPosition.spanRange[1])) {
        let spanRange: number[] = span.spanPosition.spanRange
        editorController.setSelection(spanRange[0], spanRange[1])
        return false
      }
    }
    return true
  }

  build() {
    this.richEditorBuilder(this.controller.getRichEditorController(), this.aboutToDeleteCallback)
  }
}

/** 判断是否TopicSpan */
function isTopicSpan(span: RichEditorTextSpanResult | RichEditorImageSpanResult) : boolean {
  return span['imageStyle'] != undefined && (span['valueResourceStr'] == '' || span['valueResourceStr'] == ' ')
}

export interface TopicSpan {
  id: string
  builder: CustomBuilder
}

/**
 * TopicEditor控制器，通过它添加TopicSpan和TextSpan，以及获取最终结果
 */
export class TopicEditorController {
  private internal = new RichEditorController()

  private topicIds : string[] = []

  /** 清空 */
  clear() {
    this.topicIds = []
    this.internal.deleteSpans()
  }

  /** 暴露RichEditorController以便灵活控制RichEditor */
  getRichEditorController(): RichEditorController {
		return this.internal
  }

  /**
   * 添加TopicSpan
   * @param span 话题、用户信息，ID必须唯一
   * @param offset 添加位置
   */
  addTopicSpan(span: TopicSpan, offset?: number) {
    this.topicIds.push(span.id)
    this.internal.addBuilderSpan(span.builder, { offset })
  }

  /**
   * 同RichEditorController
   * @param value
   * @param options
   * @returns
   */
  addTextSpan(value: string, options?: RichEditorTextSpanOptions | undefined): number {
    return this.internal.addTextSpan(value, options)
  }

  /**
   * 获取当前内容，数组每个元素代表一个Span，调用者可以根据返回结果和业务逻辑组合成最终内容
   */
  getSpans(): TopicSpanResult[] {
    let topicSpanInfos: TopicSpanInfo[] = []
    for (let id of this.topicIds) {
      let componentInfo = componentUtils.getRectangleById(id)

      // 宽高为0代表已经被删除了
      if(componentInfo.size.width == 0 && componentInfo.size.height == 0) {
        continue
      }
      topicSpanInfos.push({ id, componentInfo })
    }

    // 根据组件位置排序
    topicSpanInfos = topicSpanInfos.sort((a, b) => {
      if(a.componentInfo.windowOffset.y >= b.componentInfo.windowOffset.y + b.componentInfo.size.height) {
        return 1
      }
      if(a.componentInfo.windowOffset.y + a.componentInfo.size.height <= b.componentInfo.windowOffset.y) {
        return -1
      }
      return a.componentInfo.windowOffset.x - b.componentInfo.windowOffset.x
    })

    // 按序替换得到最终结果
    let results : TopicSpanResult[] = []
    let spans = this.internal.getSpans()
    let index = 0
    for (let span of spans) {
      if(isTopicSpan(span)) {
        results.push({
          value: topicSpanInfos[index++].id,
          isTopicSpan: true
        })
      } else {
        let textSpan = span as RichEditorTextSpanResult
        results.push({
          value: textSpan.value,
          isTopicSpan: false
        })
      }
    }
    return results
  }
}

interface TopicSpanInfo {
  id: string
  componentInfo : componentUtils.ComponentInfo
}

export interface TopicSpanResult {
  /** isTopicSpan为true时，这是TopicSpan的id，为false时，是TextSpan的文本 */
  value: string
  /** 此Span是否是TopicSpan */
  isTopicSpan: boolean
}
