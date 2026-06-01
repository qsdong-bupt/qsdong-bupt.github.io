// Simple numbering for non-book documents
#let equation-numbering = "(1)"
#let callout-numbering = "1"
#let subfloat-numbering(n-super, subfloat-idx) = {
  numbering("1a", n-super, subfloat-idx)
}

// Theorem configuration for theorion
// Simple numbering for non-book documents (no heading inheritance)
#let theorem-inherited-levels = 0

// Theorem numbering format (can be overridden by extensions for appendix support)
// This function returns the numbering pattern to use
#let theorem-numbering(loc) = "1.1"

// Default theorem render function
#let theorem-render(prefix: none, title: "", full-title: auto, body) = {
  if full-title != "" and full-title != auto and full-title != none {
    strong[#full-title.]
    h(0.5em)
  }
  body
}
// Some definitions presupposed by pandoc's typst output.
#let content-to-string(content) = {
  if content.has("text") {
    content.text
  } else if content.has("children") {
    content.children.map(content-to-string).join("")
  } else if content.has("body") {
    content-to-string(content.body)
  } else if content == [ ] {
    " "
  }
}

#let horizontalrule = line(start: (25%,0%), end: (75%,0%))

#let endnote(num, contents) = [
  #stack(dir: ltr, spacing: 3pt, super[#num], contents)
]

#show terms.item: it => block(breakable: false)[
  #text(weight: "bold")[#it.term]
  #block(inset: (left: 1.5em, top: -0.4em))[#it.description]
]

// Some quarto-specific definitions.

#show raw.where(block: true): set block(
    fill: luma(230),
    width: 100%,
    inset: 8pt,
    radius: 2pt
  )

#let block_with_new_content(old_block, new_content) = {
  let fields = old_block.fields()
  let _ = fields.remove("body")
  if fields.at("below", default: none) != none {
    // TODO: this is a hack because below is a "synthesized element"
    // according to the experts in the typst discord...
    fields.below = fields.below.abs
  }
  block.with(..fields)(new_content)
}

#let empty(v) = {
  if type(v) == str {
    // two dollar signs here because we're technically inside
    // a Pandoc template :grimace:
    v.matches(regex("^\\s*$")).at(0, default: none) != none
  } else if type(v) == content {
    if v.at("text", default: none) != none {
      return empty(v.text)
    }
    for child in v.at("children", default: ()) {
      if not empty(child) {
        return false
      }
    }
    return true
  }

}

// Subfloats
// This is a technique that we adapted from https://github.com/tingerrr/subpar/
#let quartosubfloatcounter = counter("quartosubfloatcounter")

#let quarto_super(
  kind: str,
  caption: none,
  label: none,
  supplement: str,
  position: none,
  subcapnumbering: "(a)",
  body,
) = {
  context {
    let figcounter = counter(figure.where(kind: kind))
    let n-super = figcounter.get().first() + 1
    set figure.caption(position: position)
    [#figure(
      kind: kind,
      supplement: supplement,
      caption: caption,
      {
        show figure.where(kind: kind): set figure(numbering: _ => {
          let subfloat-idx = quartosubfloatcounter.get().first() + 1
          subfloat-numbering(n-super, subfloat-idx)
        })
        show figure.where(kind: kind): set figure.caption(position: position)

        show figure: it => {
          let num = numbering(subcapnumbering, n-super, quartosubfloatcounter.get().first() + 1)
          show figure.caption: it => block({
            num.slice(2) // I don't understand why the numbering contains output that it really shouldn't, but this fixes it shrug?
            [ ]
            it.body
          })

          quartosubfloatcounter.step()
          it
          counter(figure.where(kind: it.kind)).update(n => n - 1)
        }

        quartosubfloatcounter.update(0)
        body
      }
    )#label]
  }
}

// callout rendering
// this is a figure show rule because callouts are crossreferenceable
#show figure: it => {
  if type(it.kind) != str {
    return it
  }
  let kind_match = it.kind.matches(regex("^quarto-callout-(.*)")).at(0, default: none)
  if kind_match == none {
    return it
  }
  let kind = kind_match.captures.at(0, default: "other")
  kind = upper(kind.first()) + kind.slice(1)
  // now we pull apart the callout and reassemble it with the crossref name and counter

  // when we cleanup pandoc's emitted code to avoid spaces this will have to change
  let old_callout = it.body.children.at(1).body.children.at(1)
  let old_title_block = old_callout.body.children.at(0)
  let children = old_title_block.body.body.children
  let old_title = if children.len() == 1 {
    children.at(0)  // no icon: title at index 0
  } else {
    children.at(1)  // with icon: title at index 1
  }

  // TODO use custom separator if available
  // Use the figure's counter display which handles chapter-based numbering
  // (when numbering is a function that includes the heading counter)
  let callout_num = it.counter.display(it.numbering)
  let new_title = if empty(old_title) {
    [#kind #callout_num]
  } else {
    [#kind #callout_num: #old_title]
  }

  let new_title_block = block_with_new_content(
    old_title_block,
    block_with_new_content(
      old_title_block.body,
      if children.len() == 1 {
        new_title  // no icon: just the title
      } else {
        children.at(0) + new_title  // with icon: preserve icon block + new title
      }))

  align(left, block_with_new_content(old_callout,
    block(below: 0pt, new_title_block) +
    old_callout.body.children.at(1)))
}

// 2023-10-09: #fa-icon("fa-info") is not working, so we'll eval "#fa-info()" instead
#let callout(body: [], title: "Callout", background_color: rgb("#dddddd"), icon: none, icon_color: black, body_background_color: white) = {
  block(
    breakable: false, 
    fill: background_color, 
    stroke: (paint: icon_color, thickness: 0.5pt, cap: "round"), 
    width: 100%, 
    radius: 2pt,
    block(
      inset: 1pt,
      width: 100%, 
      below: 0pt, 
      block(
        fill: background_color,
        width: 100%,
        inset: 8pt)[#if icon != none [#text(icon_color, weight: 900)[#icon] ]#title]) +
      if(body != []){
        block(
          inset: 1pt, 
          width: 100%, 
          block(fill: body_background_color, width: 100%, inset: 8pt, body))
      }
    )
}


// syntax highlighting functions from skylighting:
/* Function definitions for syntax highlighting generated by skylighting: */
#let EndLine() = raw("\n")
#let Skylighting(fill: none, number: false, start: 1, sourcelines) = {
   let blocks = []
   let lnum = start - 1
   let bgcolor = rgb("#f1f3f5")
   for ln in sourcelines {
     if number {
       lnum = lnum + 1
       blocks = blocks + box(width: if start + sourcelines.len() > 999 { 30pt } else { 24pt }, text(fill: rgb("#aaaaaa"), [ #lnum ]))
     }
     blocks = blocks + ln + EndLine()
   }
   block(fill: bgcolor, width: 100%, inset: 8pt, radius: 2pt, blocks)
}
#let AlertTok(s) = text(fill: rgb("#ad0000"),raw(s))
#let AnnotationTok(s) = text(fill: rgb("#5e5e5e"),raw(s))
#let AttributeTok(s) = text(fill: rgb("#657422"),raw(s))
#let BaseNTok(s) = text(fill: rgb("#ad0000"),raw(s))
#let BuiltInTok(s) = text(fill: rgb("#003b4f"),raw(s))
#let CharTok(s) = text(fill: rgb("#20794d"),raw(s))
#let CommentTok(s) = text(fill: rgb("#5e5e5e"),raw(s))
#let CommentVarTok(s) = text(style: "italic",fill: rgb("#5e5e5e"),raw(s))
#let ConstantTok(s) = text(fill: rgb("#8f5902"),raw(s))
#let ControlFlowTok(s) = text(weight: "bold",fill: rgb("#003b4f"),raw(s))
#let DataTypeTok(s) = text(fill: rgb("#ad0000"),raw(s))
#let DecValTok(s) = text(fill: rgb("#ad0000"),raw(s))
#let DocumentationTok(s) = text(style: "italic",fill: rgb("#5e5e5e"),raw(s))
#let ErrorTok(s) = text(fill: rgb("#ad0000"),raw(s))
#let ExtensionTok(s) = text(fill: rgb("#003b4f"),raw(s))
#let FloatTok(s) = text(fill: rgb("#ad0000"),raw(s))
#let FunctionTok(s) = text(fill: rgb("#4758ab"),raw(s))
#let ImportTok(s) = text(fill: rgb("#00769e"),raw(s))
#let InformationTok(s) = text(fill: rgb("#5e5e5e"),raw(s))
#let KeywordTok(s) = text(weight: "bold",fill: rgb("#003b4f"),raw(s))
#let NormalTok(s) = text(fill: rgb("#003b4f"),raw(s))
#let OperatorTok(s) = text(fill: rgb("#5e5e5e"),raw(s))
#let OtherTok(s) = text(fill: rgb("#003b4f"),raw(s))
#let PreprocessorTok(s) = text(fill: rgb("#ad0000"),raw(s))
#let RegionMarkerTok(s) = text(fill: rgb("#003b4f"),raw(s))
#let SpecialCharTok(s) = text(fill: rgb("#5e5e5e"),raw(s))
#let SpecialStringTok(s) = text(fill: rgb("#20794d"),raw(s))
#let StringTok(s) = text(fill: rgb("#20794d"),raw(s))
#let VariableTok(s) = text(fill: rgb("#111111"),raw(s))
#let VerbatimStringTok(s) = text(fill: rgb("#20794d"),raw(s))
#let WarningTok(s) = text(style: "italic",fill: rgb("#5e5e5e"),raw(s))



#let article(
  title: none,
  subtitle: none,
  authors: none,
  keywords: (),
  date: none,
  abstract-title: none,
  abstract: none,
  thanks: none,
  cols: 1,
  lang: "en",
  region: "US",
  font: none,
  fontsize: 11pt,
  title-size: 1.5em,
  subtitle-size: 1.25em,
  heading-family: none,
  heading-weight: "bold",
  heading-style: "normal",
  heading-color: black,
  heading-line-height: 0.65em,
  mathfont: none,
  codefont: none,
  linestretch: 1,
  sectionnumbering: none,
  linkcolor: none,
  citecolor: none,
  filecolor: none,
  toc: false,
  toc_title: none,
  toc_depth: none,
  toc_indent: 1.5em,
  doc,
) = {
  // Set document metadata for PDF accessibility
  set document(title: title, keywords: keywords)
  set document(
    author: authors.map(author => content-to-string(author.name)).join(", ", last: " & "),
  ) if authors != none and authors != ()
  set par(
    justify: true,
    leading: linestretch * 0.65em
  )
  set text(lang: lang,
           region: region,
           size: fontsize)
  set text(font: font) if font != none
  show math.equation: set text(font: mathfont) if mathfont != none
  show raw: set text(font: codefont) if codefont != none

  set heading(numbering: sectionnumbering)

  show link: set text(fill: rgb(content-to-string(linkcolor))) if linkcolor != none
  show ref: set text(fill: rgb(content-to-string(citecolor))) if citecolor != none
  show link: this => {
    if filecolor != none and type(this.dest) == label {
      text(this, fill: rgb(content-to-string(filecolor)))
    } else {
      text(this)
    }
   }

  let has-title-block = title != none or (authors != none and authors != ()) or date != none or abstract != none
  if has-title-block {
    place(
      top,
      float: true,
      scope: "parent",
      clearance: 4mm,
      block(below: 1em, width: 100%)[

        #if title != none {
          align(center, block(inset: 2em)[
            #set par(leading: heading-line-height) if heading-line-height != none
            #set text(font: heading-family) if heading-family != none
            #set text(weight: heading-weight)
            #set text(style: heading-style) if heading-style != "normal"
            #set text(fill: heading-color) if heading-color != black

            #text(size: title-size)[#title #if thanks != none {
              footnote(thanks, numbering: "*")
              counter(footnote).update(n => n - 1)
            }]
            #(if subtitle != none {
              parbreak()
              text(size: subtitle-size)[#subtitle]
            })
          ])
        }

        #if authors != none and authors != () {
          let count = authors.len()
          let ncols = calc.min(count, 3)
          grid(
            columns: (1fr,) * ncols,
            row-gutter: 1.5em,
            ..authors.map(author =>
                align(center)[
                  #author.name \
                  #author.affiliation \
                  #author.email
                ]
            )
          )
        }

        #if date != none {
          align(center)[#block(inset: 1em)[
            #date
          ]]
        }

        #if abstract != none {
          block(inset: 2em)[
          #text(weight: "semibold")[#abstract-title] #h(1em) #abstract
          ]
        }
      ]
    )
  }

  if toc {
    let title = if toc_title == none {
      auto
    } else {
      toc_title
    }
    block(above: 0em, below: 2em)[
    #outline(
      title: toc_title,
      depth: toc_depth,
      indent: toc_indent
    );
    ]
  }

  doc
}

#set table(
  inset: 6pt,
  stroke: none
)
#let brand-color = (:)
#let brand-color-background = (:)
#let brand-logo = (:)

#set page(
  paper: "us-letter",
  margin: (x: 1.25in, y: 1.25in),
  numbering: "1",
  columns: 1,
)

#show: doc => article(
  title: [LLM Pre-Training Project Report],
  authors: (
    ( name: [董庆森 秦郑泽],
      affiliation: [],
      email: [] ),
    ),
  date: [2026-05-20],
  lang: "en",
  toc: true,
  toc_title: [Table of contents],
  toc_depth: 3,
  doc,
)

= 进展情况
<进展情况>
项目名称：#strong[从零构建LLM]。

项目分为以下四个模块：

#table(
  columns: 3,
  align: (auto,auto,auto,),
  table.header([模块], [内容], [状态],),
  table.hline(),
  [模块一], [基础模块搭建与预训练], [已完成],
  [模块二], [后训练（SFT + RL对齐）], [待完成],
  [模块三], [系统优化（训练优化 + 推理优化）], [已完成],
  [模块四], [训练数据工程], [待完成],
)
本实验报告是用qmd文件编写，建议查看网页版（报告.html）以获得更好的阅读体验。

地址：#link("https://qsdong-bupt.github.io/posts/Projects/LLM_Pre-Training/")[报告]

= 1 About this Project
<about-this-project>
本项目从头实现了一个基于解码器（decoder-only）架构的因果 Transformer 语言模型，整体设计参考 LLaMA 模型的架构#link("https://arxiv.org/abs/2302.13971")[LLaMA (2023)] 。 和 GPT 系列一样，LLaMA 模型也是 Decoder-only 架构，但结合前人的工作做了一些改进，比如：

+ #strong[Pre-normalization] \[GPT3\]. 为了提高训练稳定性，LLaMA 对每个 transformer 子层的输入进行归一化，使用 #strong[RMSNorm] 归一化函数，Pre-normalization 由Zhang和Sennrich（2019）引入。使用 #strong[RMSNorm] 的好处是不用计算样本的均值，速度提升了 40%
+ #strong[FFN\_SWiGLU] \[PaLM\]。结构上使用门控线性单元，且为了保持 FFN 层参数数量不变，将隐藏单元的数量调整为 $2 / 3 4 d$ 而不是 PaLM 论文中的 $4 d$，同时将 ReLU 替换为 #strong[SiLU] \[Shazeer,2020\] 激活，引入以提高性能。
+ #strong[Rotary Embeddings] \[GPTNeo\]。模型的输入不再使用 positional embeddings，而是在网络的每一层添加了 positional embeddings（#strong[RoPE]），RoPE 方法由Su等人（2021）引入。

完整的模型结构图如下图所示: #box(image("assets/LLAMA架构图.png", alt: "LLAMA架构图"))

项目的核心特点包括：

- #strong[全组件自定义实现]：不依赖 PyTorch 内置的 #NormalTok("nn.Linear");、#NormalTok("nn.Embedding"); 等高层模块，所有组件（线性层、嵌入层、归一化层、注意力机制、前馈网络等）均从底层手动实现。
- #strong[现代化 Transformer 架构]：
  - #strong[RMSNorm]：均方根层归一化，替代传统的 LayerNorm
  - #strong[RoPE]（Rotary Position Embedding）：旋转位置编码
  - #strong[SwiGLU]：使用 SiLU 激活函数的门控前馈网络
  - #strong[Pre-Norm]：在注意力/FFN 之前进行归一化的残差连接结构
- #strong[BPE 分词器]：基于 GPT-2 风格的 Byte-Pair Encoding 算法，支持自定义词表大小
- #strong[完整训练流程]：包含 AdamW 优化器、余弦学习率调度、梯度裁剪、梯度累积等训练基础设施

项目代码位于 #link("basics/") 目录下，按功能模块组织到 #NormalTok("model/");、#NormalTok("train/");、#NormalTok("tokenizer/");、#NormalTok("inference/"); 等子目录中。

= 2 Create a Virtual Environment
<create-a-virtual-environment>
== 2.1 虚拟环境设置
<虚拟环境设置>
项目使用 Python 虚拟环境管理依赖，虚拟环境位于项目根目录下的 #link(".venv/")[#NormalTok(".venv/");] 文件夹中。

#Skylighting(([#CommentTok("# 创建虚拟环境");],
[#ExtensionTok("python");#NormalTok(" ");#AttributeTok("-m");#NormalTok(" venv .venv");],
[],
[#CommentTok("# 激活虚拟环境 (Windows PowerShell)");],
[#BuiltInTok(".");#DataTypeTok("\\.");#NormalTok("venv");#DataTypeTok("\\S");#NormalTok("cripts");#DataTypeTok("\\A");#NormalTok("ctivate.ps1");],
[],
[#CommentTok("# 激活虚拟环境 (Windows CMD)");],
[#ExtensionTok(".venv\\Scripts\\activate.bat");],
[],
[#CommentTok("# 激活虚拟环境 (Linux / macOS)");],
[#BuiltInTok("source");#NormalTok(" .venv/bin/activate");],));
== 2.2 核心依赖
<核心依赖>
#table(
  columns: 3,
  align: (auto,auto,auto,),
  table.header([依赖包], [版本], [用途],),
  table.hline(),
  [#NormalTok("torch");], [≥ 2.0], [深度学习框架],
  [#NormalTok("numpy");], [≥ 1.24], [数值计算],
  [#NormalTok("wandb");], [latest], [实验跟踪与日志记录],
  [#NormalTok("tqdm");], [latest], [进度条显示],
  [#NormalTok("regex");], [latest], [高级正则表达式（分词器）],
  [#NormalTok("pickle");], [内置], [词汇表和合并规则的序列化],
)
安装命令：

#Skylighting(([#ExtensionTok("pip");#NormalTok(" install torch numpy wandb tqdm regex");],));
= 3 Dataset
<dataset>
- #strong[语料]：OpenWebText（OWT），共 #strong[1,458,472,895 个 token]（约 14.58 亿）
- #strong[预处理]：原始文本 → BPE 编码 → token ID 序列 → 保存为 PyTorch 张量
- #strong[文件]：
  - #link("basics/data/owt_32768_ids_train.pkl") --- 训练集
  - #link("basics/data/owt_32768_ids_valid.pkl") --- 验证集

= 4 Tokenizer
<tokenizer>
== 4.1 BPE 训练
<bpe-训练>
#strong[文件：] #link("basics/tokenizer/train_bpe.py")

BPE（Byte-Pair Encoding）分词器训练流程：

+ #strong[基础词汇表]：以 256 个单字节（0-255）为基础，加上特殊标记（如 #NormalTok("<|endoftext|>");）
+ #strong[预分词（Pre-tokenization）]：使用 GPT-2 风格的正则表达式进行预分词：

#Skylighting(([#NormalTok("'(?:[sdmt]|ll|ve|re)| ?\\p{L}+| ?\\p{N}+| ?[^\\s\\p{L}\\p{N}]+|\\s+(?!\\S)|\\s+");],));
该正则保留英文缩写、字母序列、数字序列、标点符号和空白字符。

#block[
#set enum(numbering: "1.", start: 3)
+ #strong[训练循环]：
  - 统计所有相邻 token 对的频率（#NormalTok("pair_counts");）
  - 维护反向索引 #NormalTok("pair_to_tokens");，实现 $O \( 1 \)$ 查找受影响的 token
  - 每次选择频率最高的 token 对进行合并
  - 平局时按字节序选择最大的对
  - 更新受影响的 token 和 pair 计数
  - 重复直到词表达到目标大小
+ #strong[词表规模]：项目中训练的词表大小为 32768
]

核心合并循环：

#Skylighting(([#CommentTok("# 初始化: vocab[0..255] = 单字节; pair_counts 统计所有相邻对频率");],
[#CommentTok("# pair_to_tokens: 反向索引，O(1) 查找受影响的 token");],
[#ControlFlowTok("while");#NormalTok(" ");#BuiltInTok("len");#NormalTok("(vocab) ");#OperatorTok("<");#NormalTok(" vocab_size:");],
[#NormalTok("    ");#ControlFlowTok("if");#NormalTok(" ");#KeywordTok("not");#NormalTok(" pair_counts:");],
[#NormalTok("        ");#ControlFlowTok("break");],
[#NormalTok("    ");#CommentTok("# 选频率最高的 pair，平局选字节序最大");],
[#NormalTok("    max_count ");#OperatorTok("=");#NormalTok(" ");#BuiltInTok("max");#NormalTok("(pair_counts.values())");],
[#NormalTok("    candidates ");#OperatorTok("=");#NormalTok(" [k ");#ControlFlowTok("for");#NormalTok(" k, v ");#KeywordTok("in");#NormalTok(" pair_counts.items() ");#ControlFlowTok("if");#NormalTok(" v ");#OperatorTok("==");#NormalTok(" max_count]");],
[#NormalTok("    best_pair ");#OperatorTok("=");#NormalTok(" ");#BuiltInTok("max");#NormalTok("(candidates)");],
[#NormalTok("    merges.append(best_pair)");],
[#NormalTok("    new_token_bytes ");#OperatorTok("=");#NormalTok(" best_pair[");#DecValTok("0");#NormalTok("] ");#OperatorTok("+");#NormalTok(" best_pair[");#DecValTok("1");#NormalTok("]");],
[#NormalTok("    vocab[current_next_id] ");#OperatorTok("=");#NormalTok(" new_token_bytes");],
[#NormalTok("    current_next_id ");#OperatorTok("+=");#NormalTok(" ");#DecValTok("1");],
[],
[#NormalTok("    ");#CommentTok("# O(1) 获取受影响 tokens，更新 pair_counts 和 token_frequency_table");],
[#NormalTok("    affected_tokens ");#OperatorTok("=");#NormalTok(" ");#BuiltInTok("list");#NormalTok("(pair_to_tokens.get(best_pair, []))");],
[#NormalTok("    ");#ControlFlowTok("for");#NormalTok(" token ");#KeywordTok("in");#NormalTok(" affected_tokens:");],
[#NormalTok("        freq ");#OperatorTok("=");#NormalTok(" token_frequency_table.get(token, ");#DecValTok("0");#NormalTok(")");],
[#NormalTok("        ");#ControlFlowTok("if");#NormalTok(" freq ");#OperatorTok("==");#NormalTok(" ");#DecValTok("0");#NormalTok(":");],
[#NormalTok("            ");#ControlFlowTok("continue");],
[#NormalTok("        ");#CommentTok("# 从 pair_counts 中移除旧 token 的贡献");],
[#NormalTok("        ");#ControlFlowTok("for");#NormalTok(" i ");#KeywordTok("in");#NormalTok(" ");#BuiltInTok("range");#NormalTok("(");#BuiltInTok("len");#NormalTok("(token) ");#OperatorTok("-");#NormalTok(" ");#DecValTok("1");#NormalTok("):");],
[#NormalTok("            p ");#OperatorTok("=");#NormalTok(" (token[i], token[i");#OperatorTok("+");#DecValTok("1");#NormalTok("])");],
[#NormalTok("            pair_counts[p] ");#OperatorTok("-=");#NormalTok(" freq");],
[#NormalTok("            pair_to_tokens[p].discard(token)");],
[#NormalTok("            ");#ControlFlowTok("if");#NormalTok(" pair_counts[p] ");#OperatorTok("<=");#NormalTok(" ");#DecValTok("0");#NormalTok(":");],
[#NormalTok("                ");#KeywordTok("del");#NormalTok(" pair_counts[p]");],
[#NormalTok("        ");#CommentTok("# 合并 best_pair 后重新添加");],
[#NormalTok("        new_token_seq ");#OperatorTok("=");#NormalTok(" merge_token_sequence(token, best_pair, new_token_bytes)");],
[#NormalTok("        ");#ControlFlowTok("for");#NormalTok(" i ");#KeywordTok("in");#NormalTok(" ");#BuiltInTok("range");#NormalTok("(");#BuiltInTok("len");#NormalTok("(new_token_seq) ");#OperatorTok("-");#NormalTok(" ");#DecValTok("1");#NormalTok("):");],
[#NormalTok("            p ");#OperatorTok("=");#NormalTok(" (new_token_seq[i], new_token_seq[i");#OperatorTok("+");#DecValTok("1");#NormalTok("])");],
[#NormalTok("            pair_counts[p] ");#OperatorTok("+=");#NormalTok(" freq");],
[#NormalTok("            pair_to_tokens[p].add(new_token_seq)");],
[#NormalTok("        ");#KeywordTok("del");#NormalTok(" token_frequency_table[token]");],
[#NormalTok("        token_frequency_table[new_token_seq] ");#OperatorTok("+=");#NormalTok(" freq");],));
== 4.2 Tokenizer 类
<tokenizer-类>
#strong[文件：] #link("basics/tokenizer/tokenizer.py")

- #strong[encode(text)]：正则分割 → 逐词 BPE 合并 → token ID 查找
- #strong[decode(ids)]：ID → bytes 拼接 → UTF-8 解码
- #strong[BPE 缓存]：对已编码的词进行缓存，避免重复计算

#Skylighting(([#KeywordTok("class");#NormalTok(" Tokenizer:");],
[#NormalTok("    ");#KeywordTok("def");#NormalTok(" _get_bpe_merges(");#VariableTok("self");#NormalTok(", piece: ");#BuiltInTok("bytes");#NormalTok(") ");#OperatorTok("->");#NormalTok(" List[");#BuiltInTok("bytes");#NormalTok("]:");],
[#NormalTok("        parts ");#OperatorTok("=");#NormalTok(" [");#BuiltInTok("bytes");#NormalTok("([b]) ");#ControlFlowTok("for");#NormalTok(" b ");#KeywordTok("in");#NormalTok(" piece]    ");#CommentTok("# 单字节列表");],
[#NormalTok("        ");#ControlFlowTok("while");#NormalTok(" ");#BuiltInTok("len");#NormalTok("(parts) ");#OperatorTok(">");#NormalTok(" ");#DecValTok("1");#NormalTok(":");],
[#NormalTok("            pairs ");#OperatorTok("=");#NormalTok(" ");#BuiltInTok("set");#NormalTok("()");],
[#NormalTok("            ");#ControlFlowTok("for");#NormalTok(" i ");#KeywordTok("in");#NormalTok(" ");#BuiltInTok("range");#NormalTok("(");#BuiltInTok("len");#NormalTok("(parts) ");#OperatorTok("-");#NormalTok(" ");#DecValTok("1");#NormalTok("):");],
[#NormalTok("                pair ");#OperatorTok("=");#NormalTok(" (parts[i], parts[i");#OperatorTok("+");#DecValTok("1");#NormalTok("])");],
[#NormalTok("                ");#ControlFlowTok("if");#NormalTok(" pair ");#KeywordTok("in");#NormalTok(" ");#VariableTok("self");#NormalTok(".merges_set:");],
[#NormalTok("                    pairs.add(pair)");],
[#NormalTok("            ");#ControlFlowTok("if");#NormalTok(" ");#KeywordTok("not");#NormalTok(" pairs:");],
[#NormalTok("                ");#ControlFlowTok("break");],
[#NormalTok("            ");#CommentTok("# 选择 merges 优先级最高（最早被学习）的 pair");],
[#NormalTok("            best_pair ");#OperatorTok("=");#NormalTok(" ");#BuiltInTok("min");#NormalTok("(pairs, key");#OperatorTok("=");#KeywordTok("lambda");#NormalTok(" p: ");#VariableTok("self");#NormalTok(".merges_priority_map[p])");],
[#NormalTok("            ");#CommentTok("# 合并 best_pair");],
[#NormalTok("            new_parts ");#OperatorTok("=");#NormalTok(" []");],
[#NormalTok("            i ");#OperatorTok("=");#NormalTok(" ");#DecValTok("0");],
[#NormalTok("            ");#ControlFlowTok("while");#NormalTok(" i ");#OperatorTok("<");#NormalTok(" ");#BuiltInTok("len");#NormalTok("(parts):");],
[#NormalTok("                ");#ControlFlowTok("if");#NormalTok(" i ");#OperatorTok("<");#NormalTok(" ");#BuiltInTok("len");#NormalTok("(parts)");#OperatorTok("-");#DecValTok("1");#NormalTok(" ");#KeywordTok("and");#NormalTok(" (parts[i], parts[i");#OperatorTok("+");#DecValTok("1");#NormalTok("]) ");#OperatorTok("==");#NormalTok(" best_pair:");],
[#NormalTok("                    new_parts.append(parts[i] ");#OperatorTok("+");#NormalTok(" parts[i");#OperatorTok("+");#DecValTok("1");#NormalTok("])");],
[#NormalTok("                    i ");#OperatorTok("+=");#NormalTok(" ");#DecValTok("2");],
[#NormalTok("                ");#ControlFlowTok("else");#NormalTok(":");],
[#NormalTok("                    new_parts.append(parts[i])");],
[#NormalTok("                    i ");#OperatorTok("+=");#NormalTok(" ");#DecValTok("1");],
[#NormalTok("            parts ");#OperatorTok("=");#NormalTok(" new_parts");],
[#NormalTok("        ");#ControlFlowTok("return");#NormalTok(" parts");],
[],
[#NormalTok("    ");#KeywordTok("def");#NormalTok(" encode(");#VariableTok("self");#NormalTok(", text: ");#BuiltInTok("str");#NormalTok(") ");#OperatorTok("->");#NormalTok(" List[");#BuiltInTok("int");#NormalTok("]:");],
[#NormalTok("        ");#ControlFlowTok("if");#NormalTok(" ");#KeywordTok("not");#NormalTok(" text:");],
[#NormalTok("            ");#ControlFlowTok("return");#NormalTok(" []");],
[#NormalTok("        chunks ");#OperatorTok("=");#NormalTok(" regex.split(");#StringTok("'|'");#NormalTok(".join(");#BuiltInTok("map");#NormalTok("(regex.escape, ");#VariableTok("self");#NormalTok(".special_tokens)), text)");],
[#NormalTok("        final_ids ");#OperatorTok("=");#NormalTok(" []");],
[#NormalTok("        bpe_cache ");#OperatorTok("=");#NormalTok(" {}");],
[#NormalTok("        ");#ControlFlowTok("for");#NormalTok(" chunk ");#KeywordTok("in");#NormalTok(" chunks:");],
[#NormalTok("            ");#ControlFlowTok("if");#NormalTok(" ");#KeywordTok("not");#NormalTok(" chunk:");],
[#NormalTok("                ");#ControlFlowTok("continue");],
[#NormalTok("            ");#ControlFlowTok("if");#NormalTok(" chunk ");#KeywordTok("in");#NormalTok(" ");#VariableTok("self");#NormalTok(".special_tokens:");],
[#NormalTok("                final_ids.append(");#VariableTok("self");#NormalTok(".bytes_to_id[chunk.encode(");#StringTok("'utf-8'");#NormalTok(")])");],
[#NormalTok("            ");#ControlFlowTok("else");#NormalTok(":");],
[#NormalTok("                ");#ControlFlowTok("for");#NormalTok(" word ");#KeywordTok("in");#NormalTok(" regex.findall(PAT, chunk):");],
[#NormalTok("                    ");#ControlFlowTok("if");#NormalTok(" word ");#KeywordTok("not");#NormalTok(" ");#KeywordTok("in");#NormalTok(" bpe_cache:");],
[#NormalTok("                        bpe_cache[word] ");#OperatorTok("=");#NormalTok(" ");#VariableTok("self");#NormalTok("._get_bpe_merges(word.encode(");#StringTok("'utf-8'");#NormalTok("))");],
[#NormalTok("                    ");#ControlFlowTok("for");#NormalTok(" b ");#KeywordTok("in");#NormalTok(" bpe_cache[word]:");],
[#NormalTok("                        final_ids.append(");#VariableTok("self");#NormalTok(".bytes_to_id[b])");],
[#NormalTok("        ");#ControlFlowTok("return");#NormalTok(" final_ids");],
[],
[#NormalTok("    ");#KeywordTok("def");#NormalTok(" decode(");#VariableTok("self");#NormalTok(", token_ids: List[");#BuiltInTok("int");#NormalTok("]) ");#OperatorTok("->");#NormalTok(" ");#BuiltInTok("str");#NormalTok(":");],
[#NormalTok("        all_bytes ");#OperatorTok("=");#NormalTok(" ");#StringTok("b''");#NormalTok(".join(");#VariableTok("self");#NormalTok(".vocab[");#BuiltInTok("id");#NormalTok("] ");#ControlFlowTok("for");#NormalTok(" ");#BuiltInTok("id");#NormalTok(" ");#KeywordTok("in");#NormalTok(" token_ids)");],
[#NormalTok("        ");#ControlFlowTok("return");#NormalTok(" all_bytes.decode(");#StringTok("'utf-8'");#NormalTok(", errors");#OperatorTok("=");#StringTok("'replace'");#NormalTok(")");],));
== 4.3 数据编码
<数据编码>
#strong[文件：] #link("basics/tokenizer/encode_data.py")

将原始文本文件编码为 token ID 张量，保存为 #NormalTok(".pkl"); 文件供训练使用。

= 5 Model
<model>
模型整体架构采用 decoder-only Transformer（类似 Llama），由嵌入层、多个 Transformer 块、最终 RMSNorm 和 LM 头组成。以下逐一介绍各组件。

== 5.1 参数初始化
<参数初始化>
我们训练神经网络的目的是为了找到一组参数，使得模型在训练数据上的表 现最好。但是，如果初始参数设置不当，可能会导致模型无法收敛或者收敛到局 部最优解甚至出现梯度爆炸、梯度消失等问题。

最常见的两种参数初始化方法：#strong[Xavier 初始化]和 #strong[He 初始化]。

#strong[Xavier 初始化 (Glorot Initialization)]

Xavier 初始化由 Xavier Glorot 和 Yoshua Bengio 在 2010 年提出。 它的核心思想是保持每一层激活值的方差和反向传播时梯度的方差，在前向和反向传播中保持不变。 Xavier 初始化适用于 #strong[Sigmoid、Tanh] 等对称激活函数。

Xavier 初始化通常有两种分布形式：

- #strong[均匀分布 (Uniform)] 权重从均匀分布 $U \[ - r \, r \]$ 中采样，其中： $ r = sqrt(frac(6, upright("fan")_(i n) + upright("fan")_(o u t))) $ 均匀分布的方差为 $frac(\( b - a \)^2, 12) = r^2 / 3$。 这里的 $upright("fan")_(i n)$ 是一层网络输入神经元数量，$upright("fan")_(o u t)$ 是输出神经元数量。

- #strong[正态分布 (Normal)] 权重从均值为 0、标准差为 $sigma$ 的正态分布中采样，其中： $ sigma = sqrt(frac(2, upright("fan")_(i n) + upright("fan")_(o u t))) $ 这是由于每经过一层，权重的方差就会变成原来的 $1 / upright("fan")$，其中 $upright("fan")$ 表示这一层的神经元数量。

工作原理简述： 通过同时考虑输入和输出神经元的数量，Xavier 初始化试图在层与层之间找到一个平衡点，使得信号的方差既不会在传播中衰减，也不会无限放大。

#strong[He 初始化 (Kaiming Initialization)]

He 初始化由 Kaiming He（何凯明，残差网络也是他提出的）在 2015 年提出。 针对 Xavier 初始化在 #strong[ReLU 激活函数]上效果不佳的问题，He 初始化专门适配于 ReLU 系列激活函数。

ReLU 函数 $f \( x \) = max \( 0 \, x \)$ 的特性是，它会将所有负输入都变为 0。 这破坏了 Xavier 初始化所依赖的“激活函数关于原点对称”的假设，并导致大约一半的神经元输出为 0，从而改变了输出的方差。

He 初始化考虑到 ReLU 会将一半的输入置为零，这会使得输出方差减半。 为了补偿这一点，He 初始化在计算方差时引入了一个因子 2，其他思路与 Xavier 初始化一致。

- #strong[均匀分布 (Uniform)] 权重从均匀分布 $U \[ - r \, r \]$ 中采样，其中： $ r = sqrt(6 / upright("fan")_(i n)) $

- #strong[正态分布 (Normal)] 权重从均值为 0、标准差为 $sigma$ 的正态分布中采样，其中： $ sigma = sqrt(2 / upright("fan")_(i n)) $

之所以 Kaiming 初始化只考虑 $upright("fan")_(i n)$，是因为它更注重前向传播，对反向传播的影响考虑较少。

#strong[实验中参数初始化标准]

- #strong[词嵌入权重]：$cal(N) \( mu = 0 \, sigma^2 = 0.02^2 \)$，范围限制在 $plus.minus 3 sigma$ 以内。
- #strong[线性层权重]：$cal(N) \( mu = 0 \, sigma^2 = 0.02^2 \)$，范围限制在 $plus.minus 3 sigma$ 以内。
- #strong[RMSNorm 权重]：$1$

== 5.2 Embedding
<embedding>
#strong[文件：] #link("basics/model/embedding.py")

嵌入层将 token ID 映射为稠密向量。本实现使用自定义的 #NormalTok("nn.Parameter"); 矩阵，而非 PyTorch 内置的 #NormalTok("nn.Embedding");：

- #strong[权重矩阵]：形状为 #NormalTok("[vocab_size, d_model]"); 的可训练参数
- #strong[初始化]：使用截断正态分布（Truncated Normal），标准差 $sigma = 0.02$，截断范围 $\[ - 3 sigma \, 3 sigma \]$
- #strong[前向传播]：通过索引查找 #NormalTok("embedding_matrix[token_ids]"); 获取嵌入向量

#strong[为什么选择截断正态分布？] 标准正态分布理论上可以产生任意大的值（如 $+ 4 sigma$ 甚至 $+ 5 sigma$），这些离群值会导致少数 token 的嵌入向量初始范数过大，在注意力点积中形成异常大的权重，扰乱前几轮训练的梯度流。截断到 $\[ - 3 sigma \, 3 sigma \]$ 后，正态分布中 99.7% 的样本被完整保留，同时每个维度的绝对值永远不会超过 $3 sigma = 0.06$------相当于给初始嵌入加了硬上限，训练初期的数值更加稳定。$sigma = 0.02$ 是 GPT 系列（GPT-2/3）沿用的经验值。选用这么小的初始化的另一个重要原因是：嵌入向量和输出层的权重都很小时，模型初始输出的 logits 接近零，softmax 近似均匀分布，交叉熵损失自然从 $log \( upright("vocab_size") \)$ 附近开始（本项目词表大小为 32768，对应约为 $ln \( 32768 \) approx 10.4$）。

由于 #NormalTok("erfinv"); 不支持 #NormalTok("bfloat16");，初始化在 #NormalTok("float32"); 精度下完成后再转换为目标精度。

#Skylighting(([#KeywordTok("class");#NormalTok(" EmbeddingModule(nn.Module):");],
[#NormalTok("    ");#KeywordTok("def");#NormalTok(" ");#FunctionTok("__init__");#NormalTok("(");#VariableTok("self");#NormalTok(", vocab_size, d_model, device");#OperatorTok("=");#VariableTok("None");#NormalTok(", dtype");#OperatorTok("=");#NormalTok("torch.bfloat16):");],
[#NormalTok("        ");#BuiltInTok("super");#NormalTok("().");#FunctionTok("__init__");#NormalTok("()");],
[#NormalTok("        temp_matrix ");#OperatorTok("=");#NormalTok(" torch.empty(vocab_size, d_model, device");#OperatorTok("=");#NormalTok("device, dtype");#OperatorTok("=");#NormalTok("torch.float32)");],
[#NormalTok("        std ");#OperatorTok("=");#NormalTok(" ");#FloatTok("0.02");],
[#NormalTok("        torch.nn.init.trunc_normal_(temp_matrix, std");#OperatorTok("=");#NormalTok("std, a");#OperatorTok("=-");#DecValTok("3");#OperatorTok("*");#NormalTok("std, b");#OperatorTok("=");#DecValTok("3");#OperatorTok("*");#NormalTok("std)");],
[#NormalTok("        ");#VariableTok("self");#NormalTok(".embedding_matrix ");#OperatorTok("=");#NormalTok(" nn.Parameter(temp_matrix.to(dtype))");],
[],
[#NormalTok("    ");#KeywordTok("def");#NormalTok(" forward(");#VariableTok("self");#NormalTok(", token_ids: torch.Tensor) ");#OperatorTok("->");#NormalTok(" torch.Tensor:");],
[#NormalTok("        ");#ControlFlowTok("return");#NormalTok(" ");#VariableTok("self");#NormalTok(".embedding_matrix[token_ids]");],));
== 5.3 Linear
<linear>
#strong[文件：] #link("basics/model/Linear.py")

自定义线性层替代 PyTorch 的 #NormalTok("nn.Linear");：

- 前向传播：$y = x W^T + b$
- 权重初始化：正态分布，均值 0，标准差 $sigma = 0.02$
- 偏置初始化：均匀分布 $cal(U) \( - 1 / sqrt(d_(i n)) \, 1 / sqrt(d_(i n)) \)$
- 支持可选的偏置（#NormalTok("bias=True/False");）

#Skylighting(([#KeywordTok("class");#NormalTok(" Linear(nn.Module):");],
[#NormalTok("    ");#KeywordTok("def");#NormalTok(" ");#FunctionTok("__init__");#NormalTok("(");#VariableTok("self");#NormalTok(", in_features, out_features, device");#OperatorTok("=");#VariableTok("None");#NormalTok(", dtype");#OperatorTok("=");#VariableTok("None");#NormalTok(", bias");#OperatorTok("=");#VariableTok("True");#NormalTok("):");],
[#NormalTok("        ");#BuiltInTok("super");#NormalTok("().");#FunctionTok("__init__");#NormalTok("()");],
[#NormalTok("        ");#VariableTok("self");#NormalTok(".weight ");#OperatorTok("=");#NormalTok(" nn.Parameter(torch.empty(out_features, in_features, device");#OperatorTok("=");#NormalTok("device, dtype");#OperatorTok("=");#NormalTok("dtype))");],
[#NormalTok("        ");#VariableTok("self");#NormalTok(".bias ");#OperatorTok("=");#NormalTok(" nn.Parameter(torch.empty(out_features, device");#OperatorTok("=");#NormalTok("device, dtype");#OperatorTok("=");#NormalTok("dtype)) ");#ControlFlowTok("if");#NormalTok(" bias ");#ControlFlowTok("else");#NormalTok(" ");#VariableTok("None");],
[#NormalTok("        ");#VariableTok("self");#NormalTok("._init_weight()");],
[],
[#NormalTok("    ");#KeywordTok("def");#NormalTok(" _init_weight(");#VariableTok("self");#NormalTok("):");],
[#NormalTok("        std ");#OperatorTok("=");#NormalTok(" ");#FloatTok("0.02");],
[#NormalTok("        ");#ControlFlowTok("with");#NormalTok(" torch.no_grad():");],
[#NormalTok("            temp_weight ");#OperatorTok("=");#NormalTok(" ");#VariableTok("self");#NormalTok(".weight.to(torch.float32)");],
[#NormalTok("            torch.nn.init.normal_(temp_weight, mean");#OperatorTok("=");#FloatTok("0.0");#NormalTok(", std");#OperatorTok("=");#NormalTok("std)");],
[#NormalTok("            ");#VariableTok("self");#NormalTok(".weight.copy_(temp_weight.to(orig_dtype))");],
[#NormalTok("        ");#ControlFlowTok("if");#NormalTok(" ");#VariableTok("self");#NormalTok(".bias ");#KeywordTok("is");#NormalTok(" ");#KeywordTok("not");#NormalTok(" ");#VariableTok("None");#NormalTok(":");],
[#NormalTok("            fan_in ");#OperatorTok("=");#NormalTok(" ");#VariableTok("self");#NormalTok(".weight.shape[");#DecValTok("1");#NormalTok("]");],
[#NormalTok("            bound ");#OperatorTok("=");#NormalTok(" ");#DecValTok("1");#NormalTok(" ");#OperatorTok("/");#NormalTok(" (fan_in ");#OperatorTok("**");#NormalTok(" ");#FloatTok("0.5");#NormalTok(") ");#ControlFlowTok("if");#NormalTok(" fan_in ");#OperatorTok(">");#NormalTok(" ");#DecValTok("0");#NormalTok(" ");#ControlFlowTok("else");#NormalTok(" ");#DecValTok("0");],
[#NormalTok("            torch.nn.init.uniform_(");#VariableTok("self");#NormalTok(".bias, ");#OperatorTok("-");#NormalTok("bound, bound)");],
[],
[#NormalTok("    ");#KeywordTok("def");#NormalTok(" forward(");#VariableTok("self");#NormalTok(", x):");],
[#NormalTok("        o ");#OperatorTok("=");#NormalTok(" x ");#OperatorTok("@");#NormalTok(" ");#VariableTok("self");#NormalTok(".weight.T");],
[#NormalTok("        ");#ControlFlowTok("if");#NormalTok(" ");#VariableTok("self");#NormalTok(".bias ");#KeywordTok("is");#NormalTok(" ");#KeywordTok("not");#NormalTok(" ");#VariableTok("None");#NormalTok(":");],
[#NormalTok("            o ");#OperatorTok("=");#NormalTok(" o ");#OperatorTok("+");#NormalTok(" ");#VariableTok("self");#NormalTok(".bias");],
[#NormalTok("        ");#ControlFlowTok("return");#NormalTok(" o");],));
== 5.4 RMSNorm
<rmsnorm>
#strong[文件：] #link("basics/model/RMSnorm.py")

=== Pre-Norm vs Post-Norm
<pre-norm-vs-post-norm>
在 Transformer 中，归一化层（LayerNorm / RMSNorm）与残差连接的相对位置有两种范式，这对训练稳定性的影响至关重要。

#strong[Post-Norm（后归一化）] 是原始 Transformer（Vaswani et al., 2017）的设计------先做残差加法，再归一化：

$ upright(bold(x))_(l + 1) = upright("LayerNorm") #scale(x: 120%, y: 120%)[\(] upright(bold(x))_l + F_l \( upright(bold(x))_l \) #scale(x: 120%, y: 120%)[\)] $

其中 $F_l$ 是子层函数（注意力或 FFN），归一化包裹了残差连接。在一个完整的 Transformer Block 中：

$ upright(bold(x))_(l + 1 / 2) & = upright("LN") #scale(x: 120%, y: 120%)[\(] upright(bold(x))_l + upright("MHA") \( upright(bold(x))_l \) #scale(x: 120%, y: 120%)[\)]\
upright(bold(x))_(l + 1) & = upright("LN") #scale(x: 120%, y: 120%)[\(] upright(bold(x))_(l + 1 / 2) + upright("FFN") \( upright(bold(x))_(l + 1 / 2) \) #scale(x: 120%, y: 120%)[\)] $

#strong[Pre-Norm（前归一化）] 是现代 LLM（GPT-2/3/4、LLaMA、PaLM）的标准做法------先归一化，再做子层计算，最后残差加法：

$ upright(bold(x))_(l + 1) = upright(bold(x))_l + F_l #scale(x: 120%, y: 120%)[\(] upright("LayerNorm") \( upright(bold(x))_l \) #scale(x: 120%, y: 120%)[\)] $

$ upright(bold(x))_(l + 1 / 2) & = upright(bold(x))_l + upright("MHA") #scale(x: 120%, y: 120%)[\(] upright("LN") \( upright(bold(x))_l \) #scale(x: 120%, y: 120%)[\)]\
upright(bold(x))_(l + 1) & = upright(bold(x))_(l + 1 / 2) + upright("FFN") #scale(x: 120%, y: 120%)[\(] upright("LN") \( upright(bold(x))_(l + 1 / 2) \) #scale(x: 120%, y: 120%)[\)] $

两种范式的根本区别在于#strong[残差路径是否经过归一化]：

#table(
  columns: (32.26%, 35.48%, 32.26%),
  align: (auto,auto,auto,),
  table.header([对比维度], [Post-Norm], [Pre-Norm],),
  table.hline(),
  [残差路径], [经过 LN，非恒等映射], [恒等映射（$upright(bold(I))$），直通],
  [反向传播梯度], [通过 LN Jacobian，逐层指数衰减], [恒等项保证梯度下界 ≥ 1],
  [深层训练], [超过 \~20 层梯度消失], [GPT-3 96 层、PaLM 118 层均稳定],
  [学习率预热（warmup）], [#strong[必需]，否则发散], [#strong[不需要]，从零步即可正常训练],
  [各层贡献], [均衡，每层输出归一化], [后期层贡献递减（depth dilution）],
  [历史模型], [Transformer、BERT], [GPT-2→4、LLaMA、PaLM、Chinchilla],
)
#strong[Pre-Norm 为什么更稳定？] 从反向传播的梯度看，Post-Norm 每一层的梯度都必须通过 LayerNorm 的 Jacobian 矩阵（其特征值 \< 1），$L$ 层连乘后梯度呈指数衰减 $tilde.op O \( 1 \/ 2^(L \/ 2) \)$，深层网络早期层几乎收不到梯度。而 Pre-Norm 的残差路径是恒等映射 $upright(bold(I))$，梯度始终保底为 1：

$ nabla_(theta_i) cal(L) = frac(partial cal(L), partial upright(bold(x))_N) [product \( upright(bold(I)) + upright(bold(J))_(F_j) dot.op upright(bold(J))_(upright("LN")_j) \)] frac(partial upright(bold(x))_(i + 1), partial theta_i) $

即使子层梯度消失，恒等项 $upright(bold(I))$ 仍保证信号无损回传。Xiong et al.~(ICML 2020) 用平均场理论证明：Post-LN 在初始化时刻靠近输出层的参数的梯度期望呈 $Theta \( c_d^(N - i) \)$ 增长（$c_d > 1$），即输出层处梯度爆炸；而 Pre-LN 所有层的梯度均被 $Theta \( 1 \)$ 界限，与深度无关。

本项目采用 #strong[Pre-Norm + RMSNorm] 的组合------Pre-Norm 保证深层训练的梯度稳定性，RMSNorm 提供比 LayerNorm 更高效的计算。

=== RMSNorm 本身
<rmsnorm-本身>
RMSNorm 是 LayerNorm 的简化版本，去除了均值中心化，只保留缩放：

$ upright("RMSNorm") \( x \) = x / sqrt(upright("mean") \( x^2 \) + epsilon.alt) dot.op gamma $

- 在 #NormalTok("float32"); 精度下计算以提高数值稳定性，计算完成后转回原始精度
- 可学习的缩放参数 $gamma$（#NormalTok("weight");），初始化为全 1

移除均值计算可以带来以下好处：

- #strong[计算效率更高]：计算均值需要对所有元素求和再除以维度，这本身是一个 $O \( D \)$ 的操作。移除这一步可以减少计算量，尤其是在硬件层面上可能更高效。

- #strong[内存占用更少]：不计算和存储均值，也不需要 $beta$ 参数。

- #strong[简化模型]：参数更少，模型更简洁。

#Skylighting(([#KeywordTok("class");#NormalTok(" RMSnorm(nn.Module):");],
[#NormalTok("    ");#KeywordTok("def");#NormalTok(" ");#FunctionTok("__init__");#NormalTok("(");#VariableTok("self");#NormalTok(", d_model, eps");#OperatorTok("=");#FloatTok("1e-5");#NormalTok(", device");#OperatorTok("=");#VariableTok("None");#NormalTok(", dtype");#OperatorTok("=");#VariableTok("None");#NormalTok("):");],
[#NormalTok("        ");#BuiltInTok("super");#NormalTok("().");#FunctionTok("__init__");#NormalTok("()");],
[#NormalTok("        ");#VariableTok("self");#NormalTok(".eps ");#OperatorTok("=");#NormalTok(" eps");],
[#NormalTok("        ");#VariableTok("self");#NormalTok(".weight ");#OperatorTok("=");#NormalTok(" nn.Parameter(torch.ones(d_model, device");#OperatorTok("=");#NormalTok("device, dtype");#OperatorTok("=");#NormalTok("dtype))");],
[],
[#NormalTok("    ");#KeywordTok("def");#NormalTok(" _rms(");#VariableTok("self");#NormalTok(", x):");],
[#NormalTok("        ");#ControlFlowTok("return");#NormalTok(" ");#VariableTok("self");#NormalTok(".weight ");#OperatorTok("*");#NormalTok(" (x ");#OperatorTok("/");#NormalTok(" torch.sqrt(torch.mean(x");#OperatorTok("**");#DecValTok("2");#NormalTok(", dim");#OperatorTok("=-");#DecValTok("1");#NormalTok(", keepdim");#OperatorTok("=");#VariableTok("True");#NormalTok(") ");#OperatorTok("+");#NormalTok(" ");#VariableTok("self");#NormalTok(".eps))");],
[],
[#NormalTok("    ");#KeywordTok("def");#NormalTok(" forward(");#VariableTok("self");#NormalTok(", x):");],
[#NormalTok("        input_dtype ");#OperatorTok("=");#NormalTok(" x.dtype");],
[#NormalTok("        x ");#OperatorTok("=");#NormalTok(" x.to(torch.float32)         ");#CommentTok("# 高精度计算");],
[#NormalTok("        x_normed ");#OperatorTok("=");#NormalTok(" ");#VariableTok("self");#NormalTok("._rms(x)");],
[#NormalTok("        ");#ControlFlowTok("return");#NormalTok(" x_normed.to(input_dtype)");],));
== 5.5 RoPE
<rope>
#strong[文件：] #link("basics/model/rope.py")

=== 为什么需要位置编码？
<为什么需要位置编码>
Self-Attention 的公式为：

$ upright("Attention") \( Q \, K \, V \) = upright("softmax") (frac(Q K^T, sqrt(d_k))) V $

其中 $Q K^T$ 计算的是 token 之间的相似度权重。这个运算本质上是#strong[位置无关的]------对 "我写代码" 和 "代码写我"，Attention 看到的 token 间权重关系完全相同。显然这不符合自然语言的性质：顺序不同，语义完全不同。因此需要#strong[位置编码（Position Encoding）] 告诉模型每个 token 在序列中的位置。

位置编码分为两类：

- #strong[绝对位置编码]：给每个位置一个固定的向量标识（如原始 Transformer 的正弦位置编码），位置 0 用 $upright("PE")_0$，位置 1 用 $upright("PE")_1$，以此类推。
- #strong[相对位置编码]：关注的是两个 token 之间的#strong[距离]，而非绝对位置。例如 "我" 和 "代码" 在 "今天我写代码" 和 "我写代码" 中的相对距离都是 2，关系应当一致。

RoPE 的巧妙之处在于：它用#strong[旋转操作]注入位置信息，使得 Attention 内积天然只依赖相对位置。

=== 核心思想：从 2D 旋转出发
<核心思想从-2d-旋转出发>
在 2D 平面中，向量 $\( x \, y \)$ 逆时针旋转角度 $theta$ 得到：

$ vec(x', y') = mat(delim: "(", cos theta, - sin theta; sin theta, cos theta) vec(x, y) $ #box(image("assets/2D_Rotation_Demo.png", alt: "2D Rotation Demo"))

RoPE 的目标是找到一个位置编码函数 $f$，使得 $Q$ 和 $K$ 的内积仅依赖相对位置 $\( m - n \)$：

$ chevron.l f_q \( upright(bold(q)) \, m \) \, f_k \( upright(bold(k)) \, n \) chevron.r = g \( upright(bold(q)) \, upright(bold(k)) \, m - n \) $

RoPE 发现：这个函数 $f$ 正是#strong[旋转函数]。假设嵌入维度 $d = 2$，对位置 $m$ 上的向量 $upright(bold(q))$ 旋转 $m theta$，对位置 $n$ 上的 $upright(bold(k))$ 旋转 $n theta$：

$ f_q \( upright(bold(q)) \, m \) = R_(m theta) dot.op upright(bold(q)) \, quad f_k \( upright(bold(k)) \, n \) = R_(n theta) dot.op upright(bold(k)) $

利用三角恒等式 $cos A cos B + sin A sin B = cos \( A - B \)$ 和 $sin A cos B - cos A sin B = sin \( A - B \)$，可以证明：

$ chevron.l f_q \( upright(bold(q)) \, m \) \, f_k \( upright(bold(k)) \, n \) chevron.r = upright(bold(q))^T dot.op R_(\( m - n \) theta) dot.op upright(bold(k)) $

内积结果中的旋转矩阵仅依赖 $\( m - n \)$，#strong[绝对位置 $m$、$n$ 消失了]。这就是 RoPE 被称为”旋转位置编码”的原因------位置信息通过旋转注入，内积自动只保留相对位置。

为了将我们在二维空间中的结果推广到任意 $bold(x)_i in bb(R)^d$（其中 $d$ 为偶数），我们将 $d$ 维空间划分为 $d \/ 2$ 个子空间，并利用内积的线性性质将它们组合起来，将 $f_({ q \, k })$ 转化为：

$ f_({ q \, k }) \( bold(x)_m \, m \) = bold(R)_(Theta \, m)^d bold(W)_({ q \, k }) bold(x)_m $

其中

$ bold(R)_(Theta \, m)^d = mat(delim: "(", cos m theta_1, - sin m theta_1, 0, 0, dots.h.c, 0, 0; sin m theta_1, cos m theta_1, 0, 0, dots.h.c, 0, 0; 0, 0, cos m theta_2, - sin m theta_2, dots.h.c, 0, 0; 0, 0, sin m theta_2, cos m theta_2, dots.h.c, 0, 0; dots.v, dots.v, dots.v, dots.v, dots.down, dots.v, dots.v; 0, 0, 0, 0, dots.h.c, cos m theta_(d \/ 2), - sin m theta_(d \/ 2); 0, 0, 0, 0, dots.h.c, sin m theta_(d \/ 2), cos m theta_(d \/ 2)) $

是旋转矩阵，其预定义参数为 $Theta = { theta_i = 10000^(- 2 \( i - 1 \) \/ d) \, i in \[ 1 \, 2 \, . . . \, d \/ 2 \] }$。将我们的 RoPE 应用于自注意力机制，我们得到：

$ bold(q)_m^(⊺) bold(k)_n = \( bold(R)_(Theta \, m)^d bold(W)_q bold(x)_m \)^(⊺) \( bold(R)_(Theta \, n)^d bold(W)_k bold(x)_n \) = bold(x)^(⊺) bold(W)_q bold(R)_(Theta \, n - m)^d bold(W)_k bold(x)_n $

=== 频率设计：多频率覆盖不同距离
<频率设计多频率覆盖不同距离>
对于 $d$ 维向量，RoPE 将维度两两配对，共 $d \/ 2$ 对。第 $i$ 对使用的旋转频率为：

$ theta_i = 10000^(- 2 i \/ d) \, quad i = 0 \, 1 \, . . . \, d \/ 2 - 1 $

这个频率设计的精妙之处：

- #strong[低维度（$i$ 小）]：$theta_i$ 接近 1，频率高，旋转快 → 擅长捕捉#strong[短距离依赖]
- #strong[高维度（$i$ 大）]：$theta_i$ 接近 0，频率低，旋转慢 → 擅长捕捉#strong[长距离依赖]

由此，RoPE 用一组从高到低的频率同时建模了不同的距离尺度。

=== 完整的逐对旋转形式
<完整的逐对旋转形式>
对于位置 $m$ 上的向量 $upright(bold(x)) = \[ x_0 \, x_1 \, x_2 \, x_3 \, . . . \, x_(d - 1) \]$，RoPE 对每一对维度施加旋转：

$ upright("RoPE") \( upright(bold(x)) \, m \) = vec(x_0 cos \( m theta_0 \) - x_1 sin \( m theta_0 \), x_1 cos \( m theta_0 \) + x_0 sin \( m theta_0 \), x_2 cos \( m theta_1 \) - x_3 sin \( m theta_1 \), x_3 cos \( m theta_1 \) + x_2 sin \( m theta_1 \), dots.v) $

在 Self-Attention 中，RoPE 仅作用于 Q 和 K（V 不施加位置编码）：

$ upright("Attention") \( Q \, K \, V \) = upright("softmax") (frac(upright("RoPE") \( Q \, m \) dot.op upright("RoPE") \( K \, n \)^T, sqrt(d))) V $

=== 本项目的实现
<本项目的实现>
- 频率计算：$upright("freqs")_i = theta^(- 2 i \/ d_k)$，其中 $i = 0 \, 1 \, . . . \, d_k \/ 2 - 1$
- 预计算所有位置的正弦/余弦值并缓存（#NormalTok("cos_cache");、#NormalTok("sin_cache");）
- 前向传播时通过索引查找对应位置的正余弦值，使用高效的两两旋转公式：
  - $x'_(2 i) = x_(2 i) cos \( upright("pos") \) - x_(2 i + 1) sin \( upright("pos") \)$
  - $x'_(2 i + 1) = x_(2 i) sin \( upright("pos") \) + x_(2 i + 1) cos \( upright("pos") \)$

RoPE 相比其他位置编码有五个显著优势：

+ #strong[天然相对位置]：内积仅依赖相对位置，适合语言建模
+ #strong[良好的外推性]：配合 NTK/YaRN 等方法可泛化到更长序列
+ #strong[计算高效]：无需额外的位置嵌入参数，仅做旋转操作
+ #strong[无额外参数]：基于固定的三角函数，不增加可学习参数
+ #strong[KV Cache 友好]：缓存的 K 值无需因位置变化而重新计算位置编码

#Skylighting(([#KeywordTok("class");#NormalTok(" RoPE(nn.Module):");],
[#NormalTok("    ");#KeywordTok("def");#NormalTok(" ");#FunctionTok("__init__");#NormalTok("(");#VariableTok("self");#NormalTok(", theta, d_k, max_seq_len, device");#OperatorTok("=");#VariableTok("None");#NormalTok("):");],
[#NormalTok("        ");#BuiltInTok("super");#NormalTok("().");#FunctionTok("__init__");#NormalTok("()");],
[#NormalTok("        freqs ");#OperatorTok("=");#NormalTok(" ");#DecValTok("1");#NormalTok(" ");#OperatorTok("/");#NormalTok(" (theta ");#OperatorTok("**");#NormalTok(" (torch.arange(");#DecValTok("0");#NormalTok(", d_k, ");#DecValTok("2");#NormalTok(").");#BuiltInTok("float");#NormalTok("() ");#OperatorTok("/");#NormalTok(" d_k))   ");#CommentTok("# [d_k//2]");],
[#NormalTok("        positions ");#OperatorTok("=");#NormalTok(" torch.arange(max_seq_len)");],
[#NormalTok("        sinusoids ");#OperatorTok("=");#NormalTok(" torch.outer(positions, freqs)                         ");#CommentTok("# [max_seq_len, d_k//2]");],
[#NormalTok("        ");#VariableTok("self");#NormalTok(".register_buffer(");#StringTok("\"cos_cache\"");#NormalTok(", sinusoids.cos(), persistent");#OperatorTok("=");#VariableTok("False");#NormalTok(")");],
[#NormalTok("        ");#VariableTok("self");#NormalTok(".register_buffer(");#StringTok("\"sin_cache\"");#NormalTok(", sinusoids.sin(), persistent");#OperatorTok("=");#VariableTok("False");#NormalTok(")");],
[],
[#NormalTok("    ");#KeywordTok("def");#NormalTok(" forward(");#VariableTok("self");#NormalTok(", x, token_positions):");],
[#NormalTok("        cos ");#OperatorTok("=");#NormalTok(" ");#VariableTok("self");#NormalTok(".cos_cache[token_positions].to(x.dtype)");],
[#NormalTok("        sin ");#OperatorTok("=");#NormalTok(" ");#VariableTok("self");#NormalTok(".sin_cache[token_positions].to(x.dtype)");],
[#NormalTok("        x_even, x_odd ");#OperatorTok("=");#NormalTok(" x[..., ");#DecValTok("0");#NormalTok("::");#DecValTok("2");#NormalTok("], x[..., ");#DecValTok("1");#NormalTok("::");#DecValTok("2");#NormalTok("]");],
[#NormalTok("        out_even ");#OperatorTok("=");#NormalTok(" x_even ");#OperatorTok("*");#NormalTok(" cos ");#OperatorTok("-");#NormalTok(" x_odd ");#OperatorTok("*");#NormalTok(" sin");],
[#NormalTok("        out_odd  ");#OperatorTok("=");#NormalTok(" x_even ");#OperatorTok("*");#NormalTok(" sin ");#OperatorTok("+");#NormalTok(" x_odd ");#OperatorTok("*");#NormalTok(" cos");],
[#NormalTok("        out ");#OperatorTok("=");#NormalTok(" torch.stack([out_even, out_odd], dim");#OperatorTok("=-");#DecValTok("1");#NormalTok(")");],
[#NormalTok("        ");#ControlFlowTok("return");#NormalTok(" out.flatten(");#OperatorTok("-");#DecValTok("2");#NormalTok(")");],));
== 5.6 Softmax
<softmax>
#strong[文件：] #link("basics/model/softmax.py")

数值稳定的 Softmax 实现：

$ upright("softmax") \( x_i \) = frac(exp \( x_i - x_max \), sum_j exp \( x_j - x_max \)) $

通过减去最大值防止指数运算溢出。

#Skylighting(([#KeywordTok("def");#NormalTok(" softmax(x: torch.Tensor, dim: ");#BuiltInTok("int");#NormalTok(") ");#OperatorTok("->");#NormalTok(" torch.Tensor:");],
[#NormalTok("    x_max ");#OperatorTok("=");#NormalTok(" x.");#BuiltInTok("max");#NormalTok("(dim");#OperatorTok("=");#NormalTok("dim, keepdim");#OperatorTok("=");#VariableTok("True");#NormalTok(")[");#DecValTok("0");#NormalTok("]");],
[#NormalTok("    x_exp ");#OperatorTok("=");#NormalTok(" torch.exp(x ");#OperatorTok("-");#NormalTok(" x_max)");],
[#NormalTok("    ");#ControlFlowTok("return");#NormalTok(" x_exp ");#OperatorTok("/");#NormalTok(" x_exp.");#BuiltInTok("sum");#NormalTok("(dim");#OperatorTok("=");#NormalTok("dim, keepdim");#OperatorTok("=");#VariableTok("True");#NormalTok(")");],));
== 5.7 Multi-Head Attention
<sec-multi-head-attention>
#strong[文件：] #link("basics/model/multi_head_attention.py")

完整的因果多头注意力实现：

+ #strong[线性投影]：Q、K、V 分别通过独立的 Linear 层投影（无偏置）
+ #strong[维度变换]：#NormalTok("[batch, seq, d_model]"); → #NormalTok("[batch, n_heads, seq, head_dim]");
+ #strong[RoPE 编码]：对 Q 和 K 应用旋转位置编码
+ #strong[缩放点积注意力]：$upright("Attention") \( Q \, K \, V \) = upright("softmax") \( frac(Q K^T, sqrt(d_k)) + upright("mask") \) V$
+ #strong[因果掩码]：使用 #NormalTok("torch.tril"); 创建下三角掩码，确保每个位置只能关注其之前的 token
+ #strong[输出投影]：拼接所有注意力头后通过 W\_o 线性层

#Skylighting(([#KeywordTok("def");#NormalTok(" scaled_dot_product_attention(query, key, value, mask");#OperatorTok("=");#VariableTok("None");#NormalTok("):");],
[#NormalTok("    d_k ");#OperatorTok("=");#NormalTok(" query.size(");#OperatorTok("-");#DecValTok("1");#NormalTok(")");],
[#NormalTok("    scores ");#OperatorTok("=");#NormalTok(" torch.matmul(query, key.transpose(");#OperatorTok("-");#DecValTok("2");#NormalTok(", ");#OperatorTok("-");#DecValTok("1");#NormalTok(")) ");#OperatorTok("/");#NormalTok(" (d_k ");#OperatorTok("**");#NormalTok(" ");#FloatTok("0.5");#NormalTok(")");],
[#NormalTok("    ");#ControlFlowTok("if");#NormalTok(" mask ");#KeywordTok("is");#NormalTok(" ");#KeywordTok("not");#NormalTok(" ");#VariableTok("None");#NormalTok(":");],
[#NormalTok("        scores ");#OperatorTok("=");#NormalTok(" scores.masked_fill(mask ");#OperatorTok("==");#NormalTok(" ");#DecValTok("0");#NormalTok(", ");#BuiltInTok("float");#NormalTok("(");#StringTok("\"-inf\"");#NormalTok("))");],
[#NormalTok("    attn_weights ");#OperatorTok("=");#NormalTok(" softmax(scores, dim");#OperatorTok("=-");#DecValTok("1");#NormalTok(")");],
[#NormalTok("    ");#ControlFlowTok("return");#NormalTok(" torch.matmul(attn_weights, value)");],
[],
[#KeywordTok("class");#NormalTok(" MultiHeadAttention(nn.Module):");],
[#NormalTok("    ");#KeywordTok("def");#NormalTok(" ");#FunctionTok("__init__");#NormalTok("(");#VariableTok("self");#NormalTok(", d_model, n_heads, theta, max_seq_len, device");#OperatorTok("=");#VariableTok("None");#NormalTok(", dtype");#OperatorTok("=");#VariableTok("None");#NormalTok("):");],
[#NormalTok("        ");#BuiltInTok("super");#NormalTok("().");#FunctionTok("__init__");#NormalTok("()");],
[#NormalTok("        ");#VariableTok("self");#NormalTok(".n_heads ");#OperatorTok("=");#NormalTok(" n_heads");],
[#NormalTok("        ");#VariableTok("self");#NormalTok(".head_dim ");#OperatorTok("=");#NormalTok(" d_model ");#OperatorTok("//");#NormalTok(" n_heads");],
[#NormalTok("        ");#VariableTok("self");#NormalTok(".W_q ");#OperatorTok("=");#NormalTok(" Linear(d_model, d_model, bias");#OperatorTok("=");#VariableTok("False");#NormalTok(", device");#OperatorTok("=");#NormalTok("device, dtype");#OperatorTok("=");#NormalTok("dtype)");],
[#NormalTok("        ");#VariableTok("self");#NormalTok(".W_k ");#OperatorTok("=");#NormalTok(" Linear(d_model, d_model, bias");#OperatorTok("=");#VariableTok("False");#NormalTok(", device");#OperatorTok("=");#NormalTok("device, dtype");#OperatorTok("=");#NormalTok("dtype)");],
[#NormalTok("        ");#VariableTok("self");#NormalTok(".W_v ");#OperatorTok("=");#NormalTok(" Linear(d_model, d_model, bias");#OperatorTok("=");#VariableTok("False");#NormalTok(", device");#OperatorTok("=");#NormalTok("device, dtype");#OperatorTok("=");#NormalTok("dtype)");],
[#NormalTok("        ");#VariableTok("self");#NormalTok(".W_o ");#OperatorTok("=");#NormalTok(" Linear(d_model, d_model, bias");#OperatorTok("=");#VariableTok("False");#NormalTok(", device");#OperatorTok("=");#NormalTok("device, dtype");#OperatorTok("=");#NormalTok("dtype)");],
[#NormalTok("        ");#VariableTok("self");#NormalTok(".rope ");#OperatorTok("=");#NormalTok(" RoPE(theta, ");#VariableTok("self");#NormalTok(".head_dim, max_seq_len, device");#OperatorTok("=");#NormalTok("device)");],
[],
[#NormalTok("    ");#KeywordTok("def");#NormalTok(" _create_causal_mask(");#VariableTok("self");#NormalTok(", seq_len, device):");],
[#NormalTok("        mask ");#OperatorTok("=");#NormalTok(" torch.tril(torch.ones(seq_len, seq_len, device");#OperatorTok("=");#NormalTok("device)).");#BuiltInTok("bool");#NormalTok("()");],
[#NormalTok("        ");#ControlFlowTok("return");#NormalTok(" mask.unsqueeze(");#DecValTok("0");#NormalTok(").unsqueeze(");#DecValTok("0");#NormalTok(")");],
[],
[#NormalTok("    ");#KeywordTok("def");#NormalTok(" forward(");#VariableTok("self");#NormalTok(", x, token_positions");#OperatorTok("=");#VariableTok("None");#NormalTok("):");],
[#NormalTok("        mask ");#OperatorTok("=");#NormalTok(" ");#VariableTok("self");#NormalTok("._create_causal_mask(x.size(");#DecValTok("1");#NormalTok("), x.device)");],
[#NormalTok("        B, S, _ ");#OperatorTok("=");#NormalTok(" x.shape");],
[#NormalTok("        Q ");#OperatorTok("=");#NormalTok(" ");#VariableTok("self");#NormalTok(".W_q(x).view(B, S, ");#VariableTok("self");#NormalTok(".n_heads, ");#VariableTok("self");#NormalTok(".head_dim).transpose(");#DecValTok("1");#NormalTok(", ");#DecValTok("2");#NormalTok(")");],
[#NormalTok("        K ");#OperatorTok("=");#NormalTok(" ");#VariableTok("self");#NormalTok(".W_k(x).view(B, S, ");#VariableTok("self");#NormalTok(".n_heads, ");#VariableTok("self");#NormalTok(".head_dim).transpose(");#DecValTok("1");#NormalTok(", ");#DecValTok("2");#NormalTok(")");],
[#NormalTok("        V ");#OperatorTok("=");#NormalTok(" ");#VariableTok("self");#NormalTok(".W_v(x).view(B, S, ");#VariableTok("self");#NormalTok(".n_heads, ");#VariableTok("self");#NormalTok(".head_dim).transpose(");#DecValTok("1");#NormalTok(", ");#DecValTok("2");#NormalTok(")");],
[#NormalTok("        ");#ControlFlowTok("if");#NormalTok(" token_positions ");#KeywordTok("is");#NormalTok(" ");#KeywordTok("not");#NormalTok(" ");#VariableTok("None");#NormalTok(":");],
[#NormalTok("            Q ");#OperatorTok("=");#NormalTok(" ");#VariableTok("self");#NormalTok(".rope(Q, token_positions)");],
[#NormalTok("            K ");#OperatorTok("=");#NormalTok(" ");#VariableTok("self");#NormalTok(".rope(K, token_positions)");],
[#NormalTok("        attn_out ");#OperatorTok("=");#NormalTok(" scaled_dot_product_attention(Q, K, V, mask");#OperatorTok("=");#NormalTok("mask)");],
[#NormalTok("        attn_out ");#OperatorTok("=");#NormalTok(" attn_out.transpose(");#DecValTok("1");#NormalTok(", ");#DecValTok("2");#NormalTok(").contiguous().view(B, ");#OperatorTok("-");#DecValTok("1");#NormalTok(", ");#VariableTok("self");#NormalTok(".d_model)");],
[#NormalTok("        ");#ControlFlowTok("return");#NormalTok(" ");#VariableTok("self");#NormalTok(".W_o(attn_out)");],));
== 5.8 SwiGLU
<swiglu>
SwiGLU 的核心思想是用#strong[门控机制（Gating）]替代传统 FFN 中单一的激活函数（如 ReLU、GeLU）。标准 FFN 对输入直接做线性变换后通过激活函数，而 SwiGLU 将输入分别送入两条路径：一条经过 SiLU 激活作为”门”（gate），另一条保持线性作为”值”（value），两者逐元素相乘后再投影回原始维度。这种门控设计让网络能够#strong[自适应地控制信息流动]------门的值接近 0 时阻断信息，接近 1 时放行，接近负值时不仅阻断还能反转符号，从而赋予模型更灵活的表达能力。

#figure([
#box(image("assets/SwiGLU.png"))
], caption: figure.caption(
position: bottom, 
[
FFN vs SwiGLU
]), 
kind: "quarto-float-fig", 
supplement: "Figure", 
)


#strong[文件：] #link("basics/model/SwiGLU.py")

基于 #link("https://arxiv.org/abs/2002.05202")[Shazeer (2020)] 的 SwiGLU 激活：

$ upright("SwiGLU") \( x \) = W_2 \( upright("SiLU") \( W_1 \( x \) \) dot.circle W_3 \( x \) \) $

其中 $upright("SiLU") \( x \) = x dot.op sigma \( x \)$（$sigma$ 为 sigmoid 函数）。

- $W_1$：#NormalTok("d_model → d_ff");（gate 投影）
- $W_3$：#NormalTok("d_model → d_ff");（value 投影）
- $W_2$：#NormalTok("d_ff → d_model");（输出投影）
- 所有投影均无偏置

#Skylighting(([#KeywordTok("class");#NormalTok(" SwiGLU(nn.Module):");],
[#NormalTok("    ");#KeywordTok("def");#NormalTok(" ");#FunctionTok("__init__");#NormalTok("(");#VariableTok("self");#NormalTok(", d_model, d_ff, device");#OperatorTok("=");#VariableTok("None");#NormalTok(", dtype");#OperatorTok("=");#VariableTok("None");#NormalTok("):");],
[#NormalTok("        ");#BuiltInTok("super");#NormalTok("().");#FunctionTok("__init__");#NormalTok("()");],
[#NormalTok("        ");#VariableTok("self");#NormalTok(".w1 ");#OperatorTok("=");#NormalTok(" Linear(d_model, d_ff, bias");#OperatorTok("=");#VariableTok("False");#NormalTok(", device");#OperatorTok("=");#NormalTok("device, dtype");#OperatorTok("=");#NormalTok("dtype)");],
[#NormalTok("        ");#VariableTok("self");#NormalTok(".w2 ");#OperatorTok("=");#NormalTok(" Linear(d_ff, d_model, bias");#OperatorTok("=");#VariableTok("False");#NormalTok(", device");#OperatorTok("=");#NormalTok("device, dtype");#OperatorTok("=");#NormalTok("dtype)");],
[#NormalTok("        ");#VariableTok("self");#NormalTok(".w3 ");#OperatorTok("=");#NormalTok(" Linear(d_model, d_ff, bias");#OperatorTok("=");#VariableTok("False");#NormalTok(", device");#OperatorTok("=");#NormalTok("device, dtype");#OperatorTok("=");#NormalTok("dtype)");],
[],
[#NormalTok("    ");#KeywordTok("def");#NormalTok(" silu(");#VariableTok("self");#NormalTok(", x):");],
[#NormalTok("        ");#ControlFlowTok("return");#NormalTok(" x ");#OperatorTok("*");#NormalTok(" torch.sigmoid(x)");],
[],
[#NormalTok("    ");#KeywordTok("def");#NormalTok(" forward(");#VariableTok("self");#NormalTok(", x):");],
[#NormalTok("        ");#ControlFlowTok("return");#NormalTok(" ");#VariableTok("self");#NormalTok(".w2(");#VariableTok("self");#NormalTok(".silu(");#VariableTok("self");#NormalTok(".w1(x)) ");#OperatorTok("*");#NormalTok(" ");#VariableTok("self");#NormalTok(".w3(x))");],));
== 5.9 Transformer Block
<transformer-block>
#strong[文件：] #link("basics/model/transformer_block.py")

采用 Pre-Norm 残差结构：

#Skylighting(([#NormalTok("x → RMSNorm → Multi-Head Attention (+RoPE) → + x (残差)");],
[#NormalTok("  → RMSNorm → SwiGLU → + x1 (残差) → output");],));
#figure([
#box(image("assets/Transformer_Block_Diagram.png"))
], caption: figure.caption(
position: bottom, 
[
Transformer Block Diagram
]), 
kind: "quarto-float-fig", 
supplement: "Figure", 
)


#Skylighting(([#KeywordTok("class");#NormalTok(" transformer_block(nn.Module):");],
[#NormalTok("    ");#KeywordTok("def");#NormalTok(" ");#FunctionTok("__init__");#NormalTok("(");#VariableTok("self");#NormalTok(", d_model, n_heads, theta, max_seq_len, d_ff, device");#OperatorTok("=");#VariableTok("None");#NormalTok(", dtype");#OperatorTok("=");#VariableTok("None");#NormalTok("):");],
[#NormalTok("        ");#BuiltInTok("super");#NormalTok("().");#FunctionTok("__init__");#NormalTok("()");],
[#NormalTok("        ");#VariableTok("self");#NormalTok(".RMSnorm_1 ");#OperatorTok("=");#NormalTok(" RMSnorm(d_model, eps");#OperatorTok("=");#FloatTok("1e-5");#NormalTok(", device");#OperatorTok("=");#NormalTok("device, dtype");#OperatorTok("=");#NormalTok("dtype)");],
[#NormalTok("        ");#VariableTok("self");#NormalTok(".RMSnorm_2 ");#OperatorTok("=");#NormalTok(" RMSnorm(d_model, eps");#OperatorTok("=");#FloatTok("1e-5");#NormalTok(", device");#OperatorTok("=");#NormalTok("device, dtype");#OperatorTok("=");#NormalTok("dtype)");],
[#NormalTok("        ");#VariableTok("self");#NormalTok(".multi_head_attention ");#OperatorTok("=");#NormalTok(" MultiHeadAttention(d_model, n_heads, theta, max_seq_len, device, dtype)");],
[#NormalTok("        ");#VariableTok("self");#NormalTok(".swiglu ");#OperatorTok("=");#NormalTok(" SwiGLU(d_model, d_ff, device, dtype)");],
[],
[#NormalTok("    ");#KeywordTok("def");#NormalTok(" forward(");#VariableTok("self");#NormalTok(", x):");],
[#NormalTok("        token_positions ");#OperatorTok("=");#NormalTok(" torch.arange(x.shape[");#DecValTok("1");#NormalTok("], device");#OperatorTok("=");#NormalTok("x.device)");],
[#NormalTok("        x1 ");#OperatorTok("=");#NormalTok(" ");#VariableTok("self");#NormalTok(".RMSnorm_1(x)");],
[#NormalTok("        x1 ");#OperatorTok("=");#NormalTok(" ");#VariableTok("self");#NormalTok(".multi_head_attention(x1, token_positions)");],
[#NormalTok("        x1 ");#OperatorTok("=");#NormalTok(" x1 ");#OperatorTok("+");#NormalTok(" x                                    ");#CommentTok("# 残差连接");],
[#NormalTok("        x2 ");#OperatorTok("=");#NormalTok(" ");#VariableTok("self");#NormalTok(".RMSnorm_2(x1)");],
[#NormalTok("        x2 ");#OperatorTok("=");#NormalTok(" ");#VariableTok("self");#NormalTok(".swiglu(x2)");],
[#NormalTok("        out ");#OperatorTok("=");#NormalTok(" x2 ");#OperatorTok("+");#NormalTok(" x1                                   ");#CommentTok("# 残差连接");],
[#NormalTok("        ");#ControlFlowTok("return");#NormalTok(" out");],));
== 5.10 TransformerModule
<transformermodule>
#strong[文件：] #link("basics/model/transformermodule.py")

完整的 Transformer 模型将上述组件组合为端到端的语言模型：

#Skylighting(([#NormalTok("Token IDs → Embedding → N × TransformerBlock → RMSNorm → Linear(LM Head) → Logits");],));
#figure([
#box(image("assets/LLAMA架构图.png"))
], caption: figure.caption(
position: bottom, 
[
LLAMA架构图
]), 
kind: "quarto-float-fig", 
supplement: "Figure", 
)


#Skylighting(([#KeywordTok("class");#NormalTok(" TransformerModule(nn.Module):");],
[#NormalTok("    ");#KeywordTok("def");#NormalTok(" ");#FunctionTok("__init__");#NormalTok("(");#VariableTok("self");#NormalTok(", d_model, n_heads, theta, max_seq_len, d_ff, n_layers, vocab_size, device");#OperatorTok("=");#VariableTok("None");#NormalTok(", dtype");#OperatorTok("=");#NormalTok("torch.bfloat16):");],
[#NormalTok("        ");#BuiltInTok("super");#NormalTok("().");#FunctionTok("__init__");#NormalTok("()");],
[#NormalTok("        ");#VariableTok("self");#NormalTok(".embedding_module ");#OperatorTok("=");#NormalTok(" EmbeddingModule(vocab_size, d_model, device");#OperatorTok("=");#NormalTok("device, dtype");#OperatorTok("=");#NormalTok("dtype)");],
[#NormalTok("        ");#VariableTok("self");#NormalTok(".transformer_blocks ");#OperatorTok("=");#NormalTok(" nn.ModuleList([");],
[#NormalTok("            transformer_block(d_model, n_heads, theta, max_seq_len, d_ff, device");#OperatorTok("=");#NormalTok("device, dtype");#OperatorTok("=");#NormalTok("dtype)");],
[#NormalTok("            ");#ControlFlowTok("for");#NormalTok(" _ ");#KeywordTok("in");#NormalTok(" ");#BuiltInTok("range");#NormalTok("(n_layers)");],
[#NormalTok("        ])");],
[#NormalTok("        ");#VariableTok("self");#NormalTok(".final_norm ");#OperatorTok("=");#NormalTok(" RMSnorm(d_model, eps");#OperatorTok("=");#FloatTok("1e-5");#NormalTok(", device");#OperatorTok("=");#NormalTok("device, dtype");#OperatorTok("=");#NormalTok("dtype)");],
[#NormalTok("        ");#VariableTok("self");#NormalTok(".linear_module ");#OperatorTok("=");#NormalTok(" Linear(d_model, vocab_size, bias");#OperatorTok("=");#VariableTok("False");#NormalTok(", device");#OperatorTok("=");#NormalTok("device, dtype");#OperatorTok("=");#NormalTok("dtype)");],
[],
[#NormalTok("    ");#KeywordTok("def");#NormalTok(" forward(");#VariableTok("self");#NormalTok(", x):");],
[#NormalTok("        x ");#OperatorTok("=");#NormalTok(" ");#VariableTok("self");#NormalTok(".embedding_module(x)");],
[#NormalTok("        ");#ControlFlowTok("for");#NormalTok(" block ");#KeywordTok("in");#NormalTok(" ");#VariableTok("self");#NormalTok(".transformer_blocks:");],
[#NormalTok("            x ");#OperatorTok("=");#NormalTok(" block(x)");],
[#NormalTok("        x ");#OperatorTok("=");#NormalTok(" ");#VariableTok("self");#NormalTok(".final_norm(x)");],
[#NormalTok("        x ");#OperatorTok("=");#NormalTok(" ");#VariableTok("self");#NormalTok(".linear_module(x)");],
[#NormalTok("        ");#ControlFlowTok("return");#NormalTok(" x");],));
= 6 Pre-training Strategy
<pre-training-strategy>
== 6.1 Optimizer
<optimizer>
#strong[文件：] #link("basics/train/adamw.py")

#strong[AdamW 实现]

Adam 优化器（Kingma & Ba, 2015）将#strong[动量（Momentum）]和 #strong[RMSProp] 两种思想结合：通过一阶动量 $m_t$（梯度的指数移动平均）提供惯性、通过二阶动量 $v_t$（梯度平方的指数移动平均）为每个参数提供自适应的学习率缩放。这使得 Adam 在稀疏梯度和非平稳目标上表现优异。

然而，Adam 中存在一个被忽视的问题：#strong[L2 正则化与权重衰减在 Adam 中不等价]。在 SGD 中，对 loss 加 $lambda / 2 parallel theta parallel^2$（L2 正则化）等价于更新时令 $theta arrow.l theta - alpha lambda theta$（权重衰减）。但 Adam 的自适应学习率 $frac(1, sqrt(hat(v)_t) + epsilon.alt)$ 会作用于合并了 L2 的梯度，导致权重衰减的实际强度被每个参数的梯度历史扭曲------梯度大的参数反而受到更弱的正则化。这导致 Adam 的泛化能力往往不如 SGD。

#strong[AdamW（Loshchilov & Hutter, 2019）的核心思想]：将权重衰减从自适应梯度更新中#strong[解耦（decouple）]出来。具体而言：梯度保持 $g_t = nabla L$（不含正则化项），Adam 更新完成后再#strong[独立执行]权重衰减 $theta arrow.l theta - alpha lambda theta$。权重衰减与学习率、梯度统计三者独立，互不干扰。

自定义 AdamW 优化器基于 #link("https://arxiv.org/abs/1711.05101")[Loshchilov & Hutter (2019)]，将权重衰减从 Adam 的梯度更新中解耦：

#strong[一阶/二阶动量更新：]

$ m_t = beta_1 m_(t - 1) + \( 1 - beta_1 \) g_t $ $ v_t = beta_2 v_(t - 1) + \( 1 - beta_2 \) g_t^2 $

#strong[偏差修正：]

$ hat(m)_t = frac(m_t, 1 - beta_1^t) \, quad hat(v)_t = frac(v_t, 1 - beta_2^t) $

#strong[参数更新（Adam）：]

$ theta_t = theta_(t - 1) - alpha dot.op frac(hat(m)_t, sqrt(hat(v)_t) + epsilon.alt) $

#strong[解耦权重衰减（独立执行）：]

$ theta_t = theta_t - alpha dot.op lambda dot.op theta_(t - 1) $

其中 $lambda$ 为 #NormalTok("weight_decay");，$alpha$ 为学习率。

#Skylighting(([#KeywordTok("class");#NormalTok(" AdamW(optim.Optimizer):");],
[#NormalTok("    ");#KeywordTok("def");#NormalTok(" ");#FunctionTok("__init__");#NormalTok("(");#VariableTok("self");#NormalTok(", params, lr");#OperatorTok("=");#FloatTok("1e-3");#NormalTok(", betas");#OperatorTok("=");#NormalTok("(");#FloatTok("0.9");#NormalTok(", ");#FloatTok("0.999");#NormalTok("), eps");#OperatorTok("=");#FloatTok("1e-8");#NormalTok(", weight_decay");#OperatorTok("=");#FloatTok("1e-2");#NormalTok("):");],
[#NormalTok("        defaults ");#OperatorTok("=");#NormalTok(" ");#BuiltInTok("dict");#NormalTok("(lr");#OperatorTok("=");#NormalTok("lr, betas");#OperatorTok("=");#NormalTok("betas, eps");#OperatorTok("=");#NormalTok("eps, weight_decay");#OperatorTok("=");#NormalTok("weight_decay)");],
[#NormalTok("        ");#BuiltInTok("super");#NormalTok("().");#FunctionTok("__init__");#NormalTok("(params, defaults)");],
[],
[#NormalTok("    ");#KeywordTok("def");#NormalTok(" step(");#VariableTok("self");#NormalTok("):");],
[#NormalTok("        ");#ControlFlowTok("for");#NormalTok(" group ");#KeywordTok("in");#NormalTok(" ");#VariableTok("self");#NormalTok(".param_groups:");],
[#NormalTok("            ");#ControlFlowTok("for");#NormalTok(" p ");#KeywordTok("in");#NormalTok(" group[");#StringTok("'params'");#NormalTok("]:");],
[#NormalTok("                ");#ControlFlowTok("if");#NormalTok(" p.grad ");#KeywordTok("is");#NormalTok(" ");#VariableTok("None");#NormalTok(":");],
[#NormalTok("                    ");#ControlFlowTok("continue");],
[#NormalTok("                grad ");#OperatorTok("=");#NormalTok(" p.grad.data");],
[#NormalTok("                state ");#OperatorTok("=");#NormalTok(" ");#VariableTok("self");#NormalTok(".state[p]");],
[#NormalTok("                ");#ControlFlowTok("if");#NormalTok(" ");#BuiltInTok("len");#NormalTok("(state) ");#OperatorTok("==");#NormalTok(" ");#DecValTok("0");#NormalTok(":");],
[#NormalTok("                    state[");#StringTok("'step'");#NormalTok("] ");#OperatorTok("=");#NormalTok(" ");#DecValTok("0");],
[#NormalTok("                    state[");#StringTok("'m'");#NormalTok("] ");#OperatorTok("=");#NormalTok(" torch.zeros_like(p.data)   ");#CommentTok("# 一阶动量");],
[#NormalTok("                    state[");#StringTok("'v'");#NormalTok("] ");#OperatorTok("=");#NormalTok(" torch.zeros_like(p.data)   ");#CommentTok("# 二阶动量");],
[],
[#NormalTok("                m, v ");#OperatorTok("=");#NormalTok(" state[");#StringTok("'m'");#NormalTok("], state[");#StringTok("'v'");#NormalTok("]");],
[#NormalTok("                beta1, beta2 ");#OperatorTok("=");#NormalTok(" group[");#StringTok("'betas'");#NormalTok("]");],
[#NormalTok("                state[");#StringTok("'step'");#NormalTok("] ");#OperatorTok("+=");#NormalTok(" ");#DecValTok("1");],
[],
[#NormalTok("                ");#CommentTok("# Adam 更新（动量 + 偏差修正）");],
[#NormalTok("                m.mul_(beta1).add_(grad, alpha");#OperatorTok("=");#DecValTok("1");#NormalTok(" ");#OperatorTok("-");#NormalTok(" beta1)");],
[#NormalTok("                v.mul_(beta2).addcmul_(grad, grad, value");#OperatorTok("=");#DecValTok("1");#NormalTok(" ");#OperatorTok("-");#NormalTok(" beta2)");],
[#NormalTok("                bias_correction1 ");#OperatorTok("=");#NormalTok(" ");#DecValTok("1");#NormalTok(" ");#OperatorTok("-");#NormalTok(" beta1 ");#OperatorTok("**");#NormalTok(" state[");#StringTok("'step'");#NormalTok("]");],
[#NormalTok("                bias_correction2 ");#OperatorTok("=");#NormalTok(" ");#DecValTok("1");#NormalTok(" ");#OperatorTok("-");#NormalTok(" beta2 ");#OperatorTok("**");#NormalTok(" state[");#StringTok("'step'");#NormalTok("]");],
[#NormalTok("                step_size ");#OperatorTok("=");#NormalTok(" group[");#StringTok("'lr'");#NormalTok("] ");#OperatorTok("/");#NormalTok(" bias_correction1");],
[#NormalTok("                denom ");#OperatorTok("=");#NormalTok(" (v ");#OperatorTok("/");#NormalTok(" bias_correction2).sqrt().add_(group[");#StringTok("'eps'");#NormalTok("])");],
[#NormalTok("                p.data.addcdiv_(m, denom, value");#OperatorTok("=-");#NormalTok("step_size)");],
[],
[#NormalTok("                ");#CommentTok("# 解耦权重衰减");],
[#NormalTok("                p.data.add_(p.data, alpha");#OperatorTok("=-");#NormalTok("group[");#StringTok("'weight_decay'");#NormalTok("] ");#OperatorTok("*");#NormalTok(" group[");#StringTok("'lr'");#NormalTok("])");],));
== 6.2 CrossEntropyLoss
<crossentropyloss>
#strong[文件：] #link("basics/train/cross_entropy.py")

自定义实现的交叉熵损失，采用数值稳定的 log-softmax 计算：

$ cal(L) = - frac(1, B dot.op S) sum_(i = 1)^(B dot.op S) log P \( y_i \| x_i \) $

其中数值稳定的 log-softmax 计算为：

$ log upright("softmax") \( x_i \) = \( x_i - x_max \) - log (sum_j exp \( x_j - x_max \)) $

#strong[输入输出格式：] - 输入 #NormalTok("logits");：#NormalTok("[batch, seq, vocab_size]"); - 目标 #NormalTok("targets");：#NormalTok("[batch, seq]");（真实 token ID） - 输出：标量损失值（所有 token 位置的平均值）

#Skylighting(([#KeywordTok("class");#NormalTok(" CrossEntropyLoss:");],
[#NormalTok("    ");#KeywordTok("def");#NormalTok(" forward(");#VariableTok("self");#NormalTok(", ");#BuiltInTok("input");#NormalTok(": torch.Tensor, target: torch.Tensor):");],
[#NormalTok("        ");#CommentTok("# input: [batch, seq, vocab_size] -> [batch*seq, vocab]");],
[#NormalTok("        ");#CommentTok("# target: [batch, seq] -> [batch*seq]");],
[#NormalTok("        batch, seq, vocab ");#OperatorTok("=");#NormalTok(" ");#BuiltInTok("input");#NormalTok(".shape");],
[#NormalTok("        ");#BuiltInTok("input");#NormalTok(" ");#OperatorTok("=");#NormalTok(" ");#BuiltInTok("input");#NormalTok(".view(batch ");#OperatorTok("*");#NormalTok(" seq, vocab)");],
[#NormalTok("        target ");#OperatorTok("=");#NormalTok(" target.view(batch ");#OperatorTok("*");#NormalTok(" seq)");],
[],
[#NormalTok("        ");#CommentTok("# 数值稳定的 log_softmax");],
[#NormalTok("        max_logits ");#OperatorTok("=");#NormalTok(" torch.");#BuiltInTok("max");#NormalTok("(");#BuiltInTok("input");#NormalTok(", dim");#OperatorTok("=");#DecValTok("1");#NormalTok(", keepdim");#OperatorTok("=");#VariableTok("True");#NormalTok(").values");],
[#NormalTok("        input_shifted ");#OperatorTok("=");#NormalTok(" ");#BuiltInTok("input");#NormalTok(" ");#OperatorTok("-");#NormalTok(" max_logits");],
[#NormalTok("        log_sum_exp ");#OperatorTok("=");#NormalTok(" torch.log(torch.");#BuiltInTok("sum");#NormalTok("(torch.exp(input_shifted), dim");#OperatorTok("=");#DecValTok("1");#NormalTok(", keepdim");#OperatorTok("=");#VariableTok("True");#NormalTok("))");],
[#NormalTok("        log_softmax_out ");#OperatorTok("=");#NormalTok(" input_shifted ");#OperatorTok("-");#NormalTok(" log_sum_exp");],
[],
[#NormalTok("        log_p ");#OperatorTok("=");#NormalTok(" log_softmax_out[");#BuiltInTok("range");#NormalTok("(batch ");#OperatorTok("*");#NormalTok(" seq), target]");],
[#NormalTok("        loss ");#OperatorTok("=");#NormalTok(" ");#OperatorTok("-");#NormalTok("torch.");#BuiltInTok("sum");#NormalTok("(log_p) ");#OperatorTok("/");#NormalTok(" (batch ");#OperatorTok("*");#NormalTok(" seq)");],
[#NormalTok("        ");#ControlFlowTok("return");#NormalTok(" loss");],));
== 6.3 DataLoader
<dataloader>
#strong[文件：] #link("basics/train/dataloader.py")

语言模型的训练采用#strong[下一 token 预测]（next-token prediction）任务：

- #strong[训练批次]：随机采样 $B$ 个起始位置，取 $x = upright("data") \[ i : i + L \]$，$y = upright("data") \[ i + 1 : i + L + 1 \]$
  - 其中 $B$ 为 #NormalTok("batch_size");，$L$ 为 #NormalTok("context_length");
- #strong[验证批次]：按顺序遍历整个验证集，每次返回连续的 $B times L$ 个 token

这种设计使得模型在每个位置上都需要预测下一个 token，即语言模型的标准自监督训练方式。

#Skylighting(([#KeywordTok("class");#NormalTok(" DataLoader:");],
[#NormalTok("    ");#KeywordTok("def");#NormalTok(" ");#FunctionTok("__init__");#NormalTok("(");#VariableTok("self");#NormalTok(", dataset, batch_size, context_length, shuffle");#OperatorTok("=");#VariableTok("True");#NormalTok(", device");#OperatorTok("=");#StringTok("\"cpu\"");#NormalTok("):");],
[#NormalTok("        ");#VariableTok("self");#NormalTok(".data ");#OperatorTok("=");#NormalTok(" dataset");],
[#NormalTok("        ");#VariableTok("self");#NormalTok(".batch_size ");#OperatorTok("=");#NormalTok(" batch_size");],
[#NormalTok("        ");#VariableTok("self");#NormalTok(".context_length ");#OperatorTok("=");#NormalTok(" context_length");],
[],
[#NormalTok("    ");#KeywordTok("def");#NormalTok(" get_train_batch_data(");#VariableTok("self");#NormalTok("):");],
[#NormalTok("        max_start ");#OperatorTok("=");#NormalTok(" ");#VariableTok("self");#NormalTok(".data_len ");#OperatorTok("-");#NormalTok(" ");#VariableTok("self");#NormalTok(".context_length");],
[#NormalTok("        idxs ");#OperatorTok("=");#NormalTok(" np.random.randint(");#DecValTok("0");#NormalTok(", max_start, size");#OperatorTok("=");#NormalTok("(");#VariableTok("self");#NormalTok(".batch_size,))");],
[#NormalTok("        x ");#OperatorTok("=");#NormalTok(" np.stack([");#VariableTok("self");#NormalTok(".data[i : i ");#OperatorTok("+");#NormalTok(" ");#VariableTok("self");#NormalTok(".context_length] ");#ControlFlowTok("for");#NormalTok(" i ");#KeywordTok("in");#NormalTok(" idxs])");],
[#NormalTok("        y ");#OperatorTok("=");#NormalTok(" np.stack([");#VariableTok("self");#NormalTok(".data[i");#OperatorTok("+");#DecValTok("1");#NormalTok(" : i ");#OperatorTok("+");#NormalTok(" ");#VariableTok("self");#NormalTok(".context_length ");#OperatorTok("+");#NormalTok(" ");#DecValTok("1");#NormalTok("] ");#ControlFlowTok("for");#NormalTok(" i ");#KeywordTok("in");#NormalTok(" idxs])");],
[#NormalTok("        ");#ControlFlowTok("return");#NormalTok(" torch.tensor(x), torch.tensor(y)");],));
== 6.4 lr\_cosine\_shedule
<lr_cosine_shedule>
#strong[文件：] #link("basics/train/lr_cosine_shedule.py")

采用#strong[线性预热 + 余弦退火]策略：

$ upright("lr") \( t \) = cases(delim: "{", eta_max dot.op t / t_(upright("warmup")) & t < t_(upright("warmup")), eta_min + 1 / 2 \( eta_max - eta_min \) (1 + cos (pi dot.op frac(t - t_(upright("warmup")), t_(upright("cycle")) - t_(upright("warmup"))))) & t_(upright("warmup")) lt.eq t lt.eq t_(upright("cycle")), eta_min & t > t_(upright("cycle"))) $

其中 $eta_max = 4 times 10^(- 4)$，$eta_min = 4 times 10^(- 5)$，$t_(upright("warmup")) = 500$。

#Skylighting(([#KeywordTok("class");#NormalTok(" CosineSchedule:");],
[#NormalTok("    ");#KeywordTok("def");#NormalTok(" ");#FunctionTok("__init__");#NormalTok("(");#VariableTok("self");#NormalTok(", max_learning_rate, min_learning_rate, warmup_iters, cosine_cycle_iters):");],
[#NormalTok("        ");#VariableTok("self");#NormalTok(".max_learning_rate ");#OperatorTok("=");#NormalTok(" max_learning_rate");],
[#NormalTok("        ");#VariableTok("self");#NormalTok(".min_learning_rate ");#OperatorTok("=");#NormalTok(" min_learning_rate");],
[#NormalTok("        ");#VariableTok("self");#NormalTok(".warmup_iters ");#OperatorTok("=");#NormalTok(" warmup_iters");],
[#NormalTok("        ");#VariableTok("self");#NormalTok(".cosine_cycle_iters ");#OperatorTok("=");#NormalTok(" cosine_cycle_iters");],
[],
[#NormalTok("    ");#KeywordTok("def");#NormalTok(" ");#FunctionTok("__call__");#NormalTok("(");#VariableTok("self");#NormalTok(", it):");],
[#NormalTok("        ");#ControlFlowTok("if");#NormalTok(" it ");#OperatorTok("<");#NormalTok(" ");#VariableTok("self");#NormalTok(".warmup_iters:");],
[#NormalTok("            ");#ControlFlowTok("return");#NormalTok(" ");#VariableTok("self");#NormalTok(".max_learning_rate ");#OperatorTok("*");#NormalTok(" it ");#OperatorTok("/");#NormalTok(" ");#VariableTok("self");#NormalTok(".warmup_iters");],
[#NormalTok("        ");#ControlFlowTok("elif");#NormalTok(" it ");#OperatorTok(">");#NormalTok(" ");#VariableTok("self");#NormalTok(".cosine_cycle_iters:");],
[#NormalTok("            ");#ControlFlowTok("return");#NormalTok(" ");#VariableTok("self");#NormalTok(".min_learning_rate");],
[#NormalTok("        ");#ControlFlowTok("else");#NormalTok(":");],
[#NormalTok("            progress ");#OperatorTok("=");#NormalTok(" (it ");#OperatorTok("-");#NormalTok(" ");#VariableTok("self");#NormalTok(".warmup_iters) ");#OperatorTok("/");#NormalTok(" (");#VariableTok("self");#NormalTok(".cosine_cycle_iters ");#OperatorTok("-");#NormalTok(" ");#VariableTok("self");#NormalTok(".warmup_iters)");],
[#NormalTok("            ");#ControlFlowTok("return");#NormalTok(" ");#VariableTok("self");#NormalTok(".min_learning_rate ");#OperatorTok("+");#NormalTok(" (");#DecValTok("1");#NormalTok(" ");#OperatorTok("+");#NormalTok(" math.cos(math.pi ");#OperatorTok("*");#NormalTok(" progress)) ");#OperatorTok("*");#NormalTok(" ");#OperatorTok("\\");],
[#NormalTok("                   (");#VariableTok("self");#NormalTok(".max_learning_rate ");#OperatorTok("-");#NormalTok(" ");#VariableTok("self");#NormalTok(".min_learning_rate) ");#OperatorTok("/");#NormalTok(" ");#DecValTok("2");],));
== 6.5 gradient\_clip
<gradient_clip>
#strong[文件：] #link("basics/train/gradient_clip.py")

全局 L2 范数梯度裁剪，防止梯度爆炸：

$ g_(upright("clipped")) = cases(delim: "{", g dot.op frac(v, parallel g parallel_2 + epsilon.alt) & upright("if ") parallel g parallel_2 > v, g & upright("otherwise")) $

其中 $v = 1.0$ 为裁剪阈值，$g$ 为所有参数梯度的拼接。

#Skylighting(([#KeywordTok("class");#NormalTok(" GradientClip:");],
[#NormalTok("    ");#KeywordTok("def");#NormalTok(" ");#FunctionTok("__init__");#NormalTok("(");#VariableTok("self");#NormalTok(", parameters, max_l2_norm, epsilon");#OperatorTok("=");#FloatTok("1e-6");#NormalTok("):");],
[#NormalTok("        ");#VariableTok("self");#NormalTok(".parameters ");#OperatorTok("=");#NormalTok(" parameters");],
[#NormalTok("        ");#VariableTok("self");#NormalTok(".max_l2_norm ");#OperatorTok("=");#NormalTok(" max_l2_norm");],
[#NormalTok("        ");#VariableTok("self");#NormalTok(".epsilon ");#OperatorTok("=");#NormalTok(" epsilon");],
[],
[#NormalTok("    ");#KeywordTok("def");#NormalTok(" ");#FunctionTok("__call__");#NormalTok("(");#VariableTok("self");#NormalTok("):");],
[#NormalTok("        grads ");#OperatorTok("=");#NormalTok(" [p.grad ");#ControlFlowTok("for");#NormalTok(" p ");#KeywordTok("in");#NormalTok(" ");#VariableTok("self");#NormalTok(".parameters ");#ControlFlowTok("if");#NormalTok(" p.grad ");#KeywordTok("is");#NormalTok(" ");#KeywordTok("not");#NormalTok(" ");#VariableTok("None");#NormalTok("]");],
[#NormalTok("        all_grads ");#OperatorTok("=");#NormalTok(" torch.cat([grad.flatten() ");#ControlFlowTok("for");#NormalTok(" grad ");#KeywordTok("in");#NormalTok(" grads])");],
[#NormalTok("        grad_l2 ");#OperatorTok("=");#NormalTok(" torch.norm(all_grads, ");#DecValTok("2");#NormalTok(")");],
[#NormalTok("        ");#ControlFlowTok("if");#NormalTok(" grad_l2 ");#OperatorTok(">");#NormalTok(" ");#VariableTok("self");#NormalTok(".max_l2_norm:");],
[#NormalTok("            clip_coeff ");#OperatorTok("=");#NormalTok(" ");#VariableTok("self");#NormalTok(".max_l2_norm ");#OperatorTok("/");#NormalTok(" (grad_l2 ");#OperatorTok("+");#NormalTok(" ");#VariableTok("self");#NormalTok(".epsilon)");],
[#NormalTok("            ");#ControlFlowTok("for");#NormalTok(" grad ");#KeywordTok("in");#NormalTok(" grads:");],
[#NormalTok("                grad.mul_(clip_coeff)");],));
= 7 Pre-Training
<pre-training>
== 7.1 训练脚本
<训练脚本>
#strong[文件：] #link("basics/final_train.py")

每步训练执行以下操作：

+ #strong[梯度累积]：循环 #NormalTok("accumulation_steps"); 次：
  - 从 DataLoader 获取一个微批次
  - 前向传播计算 logits
  - 计算交叉熵损失并除以累积步数
  - 反向传播累积梯度
+ #strong[学习率调度]：根据余弦调度器更新当前步的学习率
+ #strong[梯度裁剪]：对所有参数梯度进行全局 L2 范数裁剪
+ #strong[优化器更新]：#NormalTok("optimizer.step()"); + #NormalTok("optimizer.zero_grad()");

核心训练循环代码：

#Skylighting(([#ControlFlowTok("for");#NormalTok(" epoch ");#KeywordTok("in");#NormalTok(" ");#BuiltInTok("range");#NormalTok("(start_epoch, config[");#StringTok("\"epochs\"");#NormalTok("]):");],
[#NormalTok("    total_loss ");#OperatorTok("=");#NormalTok(" ");#FloatTok("0.0");],
[#NormalTok("    ");#ControlFlowTok("for");#NormalTok(" step ");#KeywordTok("in");#NormalTok(" ");#BuiltInTok("range");#NormalTok("(global_step ");#OperatorTok("+");#NormalTok(" ");#DecValTok("1");#NormalTok(", config[");#StringTok("\"train_steps\"");#NormalTok("]):");],
[#NormalTok("        ");#CommentTok("# 梯度累积");],
[#NormalTok("        accumulated_loss ");#OperatorTok("=");#NormalTok(" ");#FloatTok("0.0");],
[#NormalTok("        ");#ControlFlowTok("for");#NormalTok(" micro_step ");#KeywordTok("in");#NormalTok(" ");#BuiltInTok("range");#NormalTok("(config[");#StringTok("\"accumulation_steps\"");#NormalTok("]):");],
[#NormalTok("            x, y ");#OperatorTok("=");#NormalTok(" train_data_loader.get_train_batch_data()");],
[#NormalTok("            x, y ");#OperatorTok("=");#NormalTok(" x.to(device), y.to(device)");],
[#NormalTok("            logits ");#OperatorTok("=");#NormalTok(" model(x)");],
[#NormalTok("            loss ");#OperatorTok("=");#NormalTok(" loss_fn.forward(logits, y) ");#OperatorTok("/");#NormalTok(" config[");#StringTok("\"accumulation_steps\"");#NormalTok("]");],
[#NormalTok("            loss.backward()");],
[#NormalTok("            accumulated_loss ");#OperatorTok("+=");#NormalTok(" loss.item()");],
[],
[#NormalTok("        ");#CommentTok("# 学习率调度");],
[#NormalTok("        new_lr ");#OperatorTok("=");#NormalTok(" lr_scheduler(global_step)");],
[#NormalTok("        ");#ControlFlowTok("for");#NormalTok(" param_group ");#KeywordTok("in");#NormalTok(" optimizer.param_groups:");],
[#NormalTok("            param_group[");#StringTok("'lr'");#NormalTok("] ");#OperatorTok("=");#NormalTok(" new_lr");],
[],
[#NormalTok("        ");#CommentTok("# 梯度裁剪");],
[#NormalTok("        GradientClip(model.parameters(), config[");#StringTok("\"grad_clip\"");#NormalTok("])()");],
[],
[#NormalTok("        optimizer.step()");],
[#NormalTok("        optimizer.zero_grad()");],
[#NormalTok("        total_loss ");#OperatorTok("+=");#NormalTok(" accumulated_loss");],
[#NormalTok("        global_step ");#OperatorTok("+=");#NormalTok(" ");#DecValTok("1");],
[],
[#NormalTok("        ");#CommentTok("# 每 10 步记录 W&B");],
[#NormalTok("        ");#ControlFlowTok("if");#NormalTok(" global_step ");#OperatorTok("%");#NormalTok(" ");#DecValTok("10");#NormalTok(" ");#OperatorTok("==");#NormalTok(" ");#DecValTok("0");#NormalTok(":");],
[#NormalTok("            wandb.log({");#StringTok("\"epoch\"");#NormalTok(": epoch, ");#StringTok("\"step\"");#NormalTok(": global_step, ");#StringTok("\"loss\"");#NormalTok(": accumulated_loss, ");#StringTok("\"lr\"");#NormalTok(": new_lr})");],
[],
[#NormalTok("        ");#CommentTok("# 每 1000 步验证 + 保存检查点");],
[#NormalTok("        ");#ControlFlowTok("if");#NormalTok(" global_step ");#OperatorTok("%");#NormalTok(" ");#DecValTok("1000");#NormalTok(" ");#OperatorTok("==");#NormalTok(" ");#DecValTok("0");#NormalTok(":");],
[#NormalTok("            avg_val_loss ");#OperatorTok("=");#NormalTok(" evaluate_validation_loss(model, valid_data_loader, loss_fn, device, val_steps");#OperatorTok("=");#DecValTok("1000");#NormalTok(")");],
[#NormalTok("            wandb.log({");#StringTok("\"epoch\"");#NormalTok(": epoch, ");#StringTok("\"step\"");#NormalTok(": global_step, ");#StringTok("\"val_loss\"");#NormalTok(": avg_val_loss})");],
[#NormalTok("            torch.save({");],
[#NormalTok("                ");#StringTok("'epoch'");#NormalTok(": epoch, ");#StringTok("'step'");#NormalTok(": global_step,");],
[#NormalTok("                ");#StringTok("'model_state_dict'");#NormalTok(": model.state_dict(),");],
[#NormalTok("                ");#StringTok("'optimizer_state_dict'");#NormalTok(": optimizer.state_dict(),");],
[#NormalTok("            }, ");#SpecialStringTok("f\"checkpoints/");#SpecialCharTok("{");#NormalTok("timestamp");#SpecialCharTok("}");#SpecialStringTok("/model_step_");#SpecialCharTok("{");#NormalTok("global_step");#SpecialCharTok("}");#SpecialStringTok(".pth\"");#NormalTok(")");],));
== 7.2 检查点与恢复
<检查点与恢复>
#strong[文件：] #link("basics/checkpoint.py")

- 每 1000 步保存一次检查点
- 每个 epoch 结束额外保存一次检查点
- 检查点包含模型权重、优化器状态、当前 epoch / step 和 W&B run id
- 支持从指定检查点恢复训练 (#link("basics/final_train.py#L35-L45")[final\_train.py:35-45])
- 检查点命名格式：#NormalTok("model_step_{step}.pth"); / #NormalTok("model_epoch_{epoch}.pth");

== 7.3 验证评估
<验证评估>
训练过程中每 1000 步进行一次验证评估（#link("basics/final_train.py#L204")[final\_train.py:204]）：

+ 将模型设为 #NormalTok("eval()"); 模式
+ 不计算梯度 (#NormalTok("torch.no_grad()");)
+ 从验证集#strong[随机采样 1000 个批次]（每批次按训练方式随机取偏移量）计算平均验证损失
+ 将验证损失记录到 W&B

此外，每个 epoch 结束时会自动保存一次检查点。

== 7.4 实验追踪
<实验追踪>
使用 #strong[Weights & Biases (W&B)] 进行实验追踪，记录以下指标：

#table(
  columns: 3,
  align: (auto,auto,auto,),
  table.header([指标], [记录频率], [含义],),
  table.hline(),
  [#NormalTok("loss");], [每 10 步], [训练损失（梯度累积后）],
  [#NormalTok("lr");], [每 10 步], [当前学习率],
  [#NormalTok("val_loss");], [每 1000 步], [验证集交叉熵损失],
)
== 7.5 推理
<推理>
#strong[文件：] #link("basics/inference/inference.py")

推理采用自回归解码：

+ #strong[温度缩放]：将 logits 除以温度参数 $T$ 后使用 softmax 转换为概率分布
+ #strong[Top-p 采样（核采样）]：从累积概率超过阈值 $p$ 的最小 token 集合中随机采样
+ #strong[自回归生成]：将采样的 token 拼接回输入序列，重复生成直到达到最大长度

#Skylighting(([#KeywordTok("def");#NormalTok(" temperature_scaling(logits, temperature");#OperatorTok("=");#FloatTok("1.0");#NormalTok("):");],
[#NormalTok("    probabilities ");#OperatorTok("=");#NormalTok(" torch.softmax(logits[:, ");#OperatorTok("-");#DecValTok("1");#NormalTok(", :] ");#OperatorTok("/");#NormalTok(" temperature, dim");#OperatorTok("=-");#DecValTok("1");#NormalTok(")");],
[#NormalTok("    ");#ControlFlowTok("return");#NormalTok(" probabilities");],
[],
[#KeywordTok("def");#NormalTok(" top_p_sampling(probabilities, top_p");#OperatorTok("=");#FloatTok("0.9");#NormalTok("):");],
[#NormalTok("    sort_probs, idx ");#OperatorTok("=");#NormalTok(" torch.sort(probabilities, dim");#OperatorTok("=-");#DecValTok("1");#NormalTok(", descending");#OperatorTok("=");#VariableTok("True");#NormalTok(")");],
[#NormalTok("    cumulative ");#OperatorTok("=");#NormalTok(" torch.cumsum(sort_probs, dim");#OperatorTok("=-");#DecValTok("1");#NormalTok(")");],
[#NormalTok("    mask ");#OperatorTok("=");#NormalTok(" cumulative ");#OperatorTok(">");#NormalTok(" top_p");],
[#NormalTok("    mask[..., ");#DecValTok("1");#NormalTok(":] ");#OperatorTok("=");#NormalTok(" mask[..., :");#OperatorTok("-");#DecValTok("1");#NormalTok("].clone()     ");#CommentTok("# 确保至少保留一个 token");],
[#NormalTok("    mask[..., ");#DecValTok("0");#NormalTok("] ");#OperatorTok("=");#NormalTok(" ");#DecValTok("0");],
[#NormalTok("    sort_probs[mask] ");#OperatorTok("=");#NormalTok(" ");#DecValTok("0");],
[#NormalTok("    sort_probs.div_(sort_probs.");#BuiltInTok("sum");#NormalTok("(dim");#OperatorTok("=-");#DecValTok("1");#NormalTok(", keepdim");#OperatorTok("=");#VariableTok("True");#NormalTok("))");],
[#NormalTok("    next_token_idx ");#OperatorTok("=");#NormalTok(" torch.multinomial(sort_probs, ");#DecValTok("1");#NormalTok(")");],
[#NormalTok("    ");#ControlFlowTok("return");#NormalTok(" torch.gather(idx, dim");#OperatorTok("=-");#DecValTok("1");#NormalTok(", index");#OperatorTok("=");#NormalTok("next_token_idx)");],
[],
[#KeywordTok("def");#NormalTok(" decode_token(input_tokens, model, max_tokens_to_generate, top_p");#OperatorTok("=");#FloatTok("0.9");#NormalTok(", temperature");#OperatorTok("=");#FloatTok("1.0");#NormalTok("):");],
[#NormalTok("    model.");#BuiltInTok("eval");#NormalTok("()");],
[#NormalTok("    input_tokens ");#OperatorTok("=");#NormalTok(" torch.tensor(input_tokens).unsqueeze(");#DecValTok("0");#NormalTok(")");],
[#NormalTok("    ");#ControlFlowTok("with");#NormalTok(" torch.no_grad():");],
[#NormalTok("        ");#ControlFlowTok("for");#NormalTok(" _ ");#KeywordTok("in");#NormalTok(" ");#BuiltInTok("range");#NormalTok("(max_tokens_to_generate):");],
[#NormalTok("            logits ");#OperatorTok("=");#NormalTok(" model(input_tokens)");],
[#NormalTok("            probs ");#OperatorTok("=");#NormalTok(" temperature_scaling(logits, temperature)");],
[#NormalTok("            next_token ");#OperatorTok("=");#NormalTok(" top_p_sampling(probs, top_p)");],
[#NormalTok("            input_tokens ");#OperatorTok("=");#NormalTok(" torch.cat([input_tokens, next_token], dim");#OperatorTok("=-");#DecValTok("1");#NormalTok(")");],
[#NormalTok("    ");#ControlFlowTok("return");#NormalTok(" input_tokens");],));
= 8 Pre-Training details
<pre-training-details>
== 8.1 训练配置
<训练配置>
- 训练设备：CUDA GPU 4090
- 数据类型：bfloat16（混合精度），float32 用于需要高精度的操作（如 RMSNorm）
- 总训练 token 数：1,458,472,895（约 14.58 亿）

=== 训练配置
<训练配置-1>
#table(
  columns: 3,
  align: (auto,auto,auto,),
  table.header([超参数], [值], [说明],),
  table.hline(),
  [#NormalTok("micro_batch_size");], [32], [单步批次大小（受显存限制）],
  [#NormalTok("effective_batch_size");], [256], [等效批次大小],
  [#NormalTok("accumulation_steps");], [8], [梯度累积步数],
  [#NormalTok("max_learning_rate");], [4e-4], [峰值学习率],
  [#NormalTok("min_learning_rate");], [4e-5], [最小学习率],
  [#NormalTok("lr_warmup_steps");], [500], [学习率预热步数],
  [#NormalTok("weight_decay");], [0.1], [权重衰减系数],
  [#NormalTok("grad_clip");], [1.0], [梯度裁剪的 L2 范数阈值],
  [#NormalTok("epochs");], [1], [训练轮数（全量数据）],
  [#NormalTok("context_length");], [768], [上下文窗口],
)
=== 初始化参数：
<初始化参数>
#table(
  columns: 3,
  align: (auto,auto,auto,),
  table.header([参数], [含义], [值],),
  table.hline(),
  [#NormalTok("d_model");], [隐藏层维度], [768],
  [#NormalTok("n_heads");], [注意力头数], [8],
  [#NormalTok("n_layers");], [Transformer 块数], [8],
  [#NormalTok("d_ff");], [FFN 中间层维度], [2048],
  [#NormalTok("vocab_size");], [词汇表大小], [32768],
  [#NormalTok("max_seq_len");], [最大序列长度], [768],
  [#NormalTok("rope_theta");], [RoPE 频率底数], [10000.0],
)
=== 参数量：
<参数量>
#table(
  columns: (26.09%, 39.13%, 34.78%),
  align: (auto,auto,auto,),
  table.header([组件], [计算公式], [参数量],),
  table.hline(),
  [Embedding], [#NormalTok("vocab_size × d_model"); = 32768 × 768], [25,165,824],
  [Attention], [4 × #NormalTok("d_model²"); = 4 × 768²], [2,359,296 × 8 = 18,874,368],
  [SwiGLU], [3 × #NormalTok("d_model × d_ff"); = 3 × 768 × 2048], [4,718,592 × 8 = 37,748,736],
  [RMSNorm], [#NormalTok("d_model"); = 768], [768 × 17 = 13,056],
  [LM Head], [与 Embedding 权重共享（tied）], [0],
  [#strong[合计]], [], [#strong[≈ 81.80M（约 80M）]],
)
其中 8 个 Transformer Block 共约 56.64M 参数，占总参数量的 69%；Embedding 层约 25.17M，占 31%。

== 8.2 BPE
<bpe>
BPE（Byte-Pair Encoding）分词器的训练与数据编码是预训练的前置步骤。本项目在 OpenWebText 数据集上的实际运行耗时：

- #strong[BPE 训练]：从原始文本语料中学习词汇表（词表大小 32768），约耗时 #strong[2 小时]，占内存约 #strong[64 GB]
- #strong[数据编码]：将训练好的 BPE 模型应用于全部语料（约 14.58 亿 token），将原始文本转换为 token ID 序列，约耗时 #strong[20 分钟]

== 8.3 pre-training
<pre-training-1>
模型（80M 参数）在单张 NVIDIA RTX 4090（24 GB 显存）上完成 1 个 epoch 的完整预训练，共处理约 14.58 亿 token，训练耗时约 #strong[6 小时]。以下为训练过程中的关键曲线：

- #strong[训练损失曲线]：损失从约 10.4（接近 $ln \( 32768 \)$，即初始均匀分布对应的交叉熵）逐步下降，训练初期下降最快，随后进入平稳下降阶段，最终在3.45附近，未观察到明显的过拟合或发散迹象。 #box(image("assets/loss.png", alt: "损失曲线"))
- #strong[验证损失曲线]：每 1000 步评估一次验证损失，整体趋势与训练损失一致且始终略高于训练损失，二者之间未见明显 gap，说明模型泛化良好。 #box(image("assets/val_loss.png", alt: "验证损失曲线"))
- #strong[学习率曲线]：采用线性预热（前 500 步）+ 余弦退火策略，学习率从 0 线性增至峰值 4e-4 后沿余弦曲线衰减至最小值 4e-5。 #box(image("assets/lr.png", alt: "学习率曲线"))

== 8.4 结果
<结果>
预训练完成后，我们从验证集中挑选了 4 个不同领域的文本片段（新闻时事、技术科学、文学叙事、百科知识），分别截取其中一部分作为 Prompt 输入模型进行续写，观察模型的生成能力和局限性。

#strong[生成样例]（模型输出续写部分）：

#table(
  columns: (33.33%, 33.33%, 33.33%),
  align: (auto,auto,auto,),
  table.header([领域], [Prompt（截取）], [模型续写（截取）],),
  table.hline(),
  [新闻时事], [#emph[\(CNN) -- A gunman critically injured a doctor at Johns Hopkins Hospital in Baltimore, Maryland, and later killed himself and his mother, police say.]], [A spokesman for the Ronald Johns Hopkins Medical Center told the Washington Post at the time, "We have thoughts on our deceased patient." The director of the facility, Peter Davie, said at a hearing… President Trump said last week that he was aware of the safety concerns with a female spokesperson…],
  [技术科学], [#emph[In recent years, research on quantum information has achieved a series of remarkable results.]], [Quantum energy in quantum systems is known as "a quantum particle of quantum quantity" and by talking about atomic combinations in the language. In the discovery of this paper we show how the electric field and the quantum combination can respond to quantum activities…],
  [文学叙事], [#emph["Back, are you?" said Aberforth. "What happened here?" Albus replied, though he could already guess.]], ["I'm keeping you all out here." Her voice turned to roar, but she turned and the shadows settled to shadows. Albus could feel it, but it was too many things. "Are you still in prison?" his voice caught up with his face, but his eyes still looked just the same as his father's…],
  [百科知识], [#emph[Traces of ancient civilization to be searched in Adıyaman. Following the expropriation works, excavation activities will be carried out in the ancient city of Perre, one of the five big cities of the Commagene civilization.]], [With its cultivation the most clearly defined areas were Kazakhstan (organic and ancient) and southeast Syria (recognised by Istanbul). In recent years, this number has gone from 10,000 to 60,000, especially the Brahmin cities (Paramural, Stadebel, Pina Galathi, Samajtar…)],
)
模型能够生成语法通顺、结构合理的英文文本，续写内容在句法和局部语义上基本连贯。但受限于 80M 参数量级和仅 1 个 epoch 的训练，输出存在以下局限：

- #block[
  #set enum(numbering: "(1)", start: 1)
  + 事实性错误较多，如编造人名、地名、事件；
  ]
- #block[
  #set enum(numbering: "(1)", start: 2)
  + 长距离逻辑一致性较弱，主题漂移明显；
  ]
- #block[
  #set enum(numbering: "(1)", start: 3)
  + 偶有重复生成或提前输出 #NormalTok("<|endoftext|>"); 终止符。
  ]

= 9 实验
<实验>
== 9.1 Chinchilla 缩放定律
<chinchilla-缩放定律>
在大语言模型预训练中，一个核心问题是如何在#strong[给定的计算预算（FLOPs）]下，最优地分配#strong[模型参数量 $N$] 和#strong[训练数据量 $D$]（token 数）。DeepMind 的 Chinchilla 论文（Hoffmann et al., 2022）通过大规模实验系统性地回答了这个问题。

#strong[背景：Kaplan et al.~(2020) 的结论]

OpenAI 的 Kaplan et al.~(2020) 最早研究了缩放定律，其主要结论为：给定计算预算 $C$，模型大小的最优缩放指数为 $N_(upright("opt")) prop C^0.73$，而数据量的最优缩放指数为 $D_(upright("opt")) prop C^0.27$。这意味着计算预算增加时，模型大小应比数据量增长得更快。这一结论深刻影响了 GPT-3 等大模型的训练策略------当时的普遍做法是训练越来越大的模型，但在相对较少的数据上训练不足（undertraining）。

#strong[Chinchilla 的三条实验路线]

Chinchilla 论文通过三条独立路线得出了不同于 Kaplan et al.~的结论：

+ #strong[方法一：固定模型大小，变化数据量]。对 9 种不同大小的模型（70M 至 16B），分别在 4 种不同数据量上训练，观察损失随 $N$ 和 $D$ 的变化。
+ #strong[方法二：IsoFLOP 剖面]。固定 9 种不同的计算预算（$6 times 10^17$ 至 $3 times 10^21$ FLOPs），对每种预算变化模型大小，寻找使损失最小的最优 $N$ 和 $D$ 组合。
+ #strong[方法三：参数化损失函数拟合]。将损失建模为 $L \( N \, D \) = E + A / N^alpha + B / D^beta$，通过拟合所有实验数据点确定参数 $E$、$A$、$B$、$alpha$、$beta$，进而推导出任意计算预算下的最优配置。

三种方法得出了高度一致的结论。

#strong[核心结论]

Chinchilla 的最终参数拟合结果为：

$ L \( N \, D \) = 1.69 + 406.4 / N^0.34 + 410.7 / D^0.28 $

其中 $E = 1.69$ 为不可约损失（数据的熵），$alpha = 0.34$ 和 $beta = 0.28$ 分别控制模型容量和数据量对损失下降的贡献速率。由此推导出计算最优配置：

$ N_(upright("opt")) prop C^0.50 \, quad D_(upright("opt")) prop C^0.50 $

即#strong[模型大小和训练数据量应当等比例缩放]------计算预算翻倍时，模型参数量和训练 token 数应同时翻倍。这一结论与 Kaplan et al.~的 $N_(upright("opt")) prop C^0.73$ 有本质区别。

#strong[Chinchilla 缩放定律验证]

本项目训练了 80M 参数的模型，计算量 6h 4090，处理了约 14.58 亿 token（1 个 epoch），loss = 3.45 。 $D \/ N approx 19$：

#table(
  columns: (26.09%, 39.13%, 34.78%),
  align: (auto,auto,auto,),
  table.header([组件], [计算公式], [参数量],),
  table.hline(),
  [Embedding], [#NormalTok("vocab_size × d_model"); = 32768 × 768], [25,165,824],
  [Attention], [4 × #NormalTok("d_model²"); = 4 × 768²], [2,359,296 × 8 = 18,874,368],
  [SwiGLU], [3 × #NormalTok("d_model × d_ff"); = 3 × 768 × 2048], [4,718,592 × 8 = 37,748,736],
  [RMSNorm], [#NormalTok("d_model"); = 768], [768 × 17 = 13,056],
  [LM Head], [与 Embedding 权重共享（tied）], [0],
  [#strong[合计]], [], [#strong[≈ 81.80M（约 80M）]],
)
此外，本项目还训练了一个更大的 185M 参数模型作为对比，计算量 6h 4090，处理了约 6.3 亿 token，loss = 3.35 ， $D \/ N approx 3.4$，

#table(
  columns: (26.09%, 39.13%, 34.78%),
  align: (auto,auto,auto,),
  table.header([组件], [计算公式], [参数量],),
  table.hline(),
  [Embedding], [#NormalTok("vocab_size × d_model"); = 32768 × 1024], [33,554,432],
  [Attention], [4 × #NormalTok("d_model²"); = 4 × 1024²], [4,194,304 × 12 = 50,331,648],
  [SwiGLU], [3 × #NormalTok("d_model × d_ff"); = 3 × 1024 × 3072], [9437184 × 12 = 113246208],
  [RMSNorm], [#NormalTok("d_model"); = 1024], [1024 × 25 = 25,600],
  [LM Head], [与 Embedding 权重共享（tied）], [0],
  [#strong[合计]], [], [#strong[≈ 197.13M（约 197M）]],
)
从主观上来看，80M 参数模型的 $D \/ N$ 比较接近最优值（约 20），而 197M 参数模型的 $D \/ N$ 明显偏低（约 3），因此 80M 模型的训练效率更高，损失更低。

为了证明这一点，我从验证集中抽出八个类别1000条数据的子集，分别用两个模型进行推理，并用deepseekv4模型对结果进行打分来评判模型的生成质量，结果如下：

#table(
  columns: 3,
  align: (auto,auto,auto,),
  table.header([轮数], [80M（win）], [197M（win）],),
  table.hline(),
  [1], [483], [517],
  [2], [471], [529],
  [3], [490], [510],
)
#strong[实验结果分析与讨论]

实验结果显示 80M 与 197M 模型在生成质量上整体接近，197M 模型甚至略占优势（三轮 pairwise 评测平均胜率约 51.9% vs 48.1%）。这与最初的直觉预期------80M 模型的 $D \/ N approx 18.3$ 更接近 Chinchilla 最优比例 20，应当明显优于 $D \/ N approx 3.4$ 的 197M 模型------并不一致。

然而，重新审视 Chinchilla 论文的 IsoFLOP 曲线后可以发现，这一结果实际上与 Chinchilla 的结论完全吻合。 #box(image("assets/Chinchilla.png", alt: "Chinchilla IsoFLOP 曲线")) 本实验的计算条件为单张 RTX 4090 训练约 6 小时，有效算力预估在 $tilde.op 1 times 10^18$ FLOPs 量级。对应 Chinchilla IsoFLOP 曲线，该算力水平下的最优模型规模恰好在 100M 参数量级附近，且曲线在 100M 右侧已趋于平缓------这意味着在 80M 到 197M 区间内，模型损失对参数量的变化并不敏感。因此，197M 模型与 80M 模型表现相近甚至略优，是 IsoFLOP 曲线平坦区域的必然结果，而非对 Chinchilla 定律的反驳。本实验从侧面验证了 Chinchilla 的结论，同时也揭示了一个重要的实践启示：#strong[在低算力预算（如 $tilde.op 10^18$ FLOPs）下，最优 $D \/ N$ 比例远小于经典建议的 20，应当优先保证模型参数量，而非追求数据量的匹配。]

== 9.2 kv\_cache
<kv_cache>
=== KV Cache 的核心思想
<kv-cache-的核心思想>
KV Cache 是 Transformer 解码器在自回归推理阶段的核心优化技术。在标准的自回归（autoregressive）解码中，模型逐 token 生成序列：给定已有的 $N$ 个 token，预测第 $N + 1$ 个 token；然后将第 $N + 1$ 个 token 拼接到输入中，继续预测第 $N + 2$ 个 token，以此类推。这一机制的瓶颈在于------每一步都需要对整个序列重新计算注意力。

具体来说，在第 $N$ 步解码时，输入序列长度为 $N$，注意力矩阵 $Q K^T$ 的尺寸为 $N times N$，其计算量随 $N$ 线性增长，总解码 $N$ 个 token 的计算复杂度为 $O \( N^2 \)$。然而，观察 self-attention 的计算过程可以发现：对于已经计算过的历史 token，其键向量 $K$ 和值向量 $V$ 在后续步骤中#strong[完全不变]------因为因果掩码（causal mask）确保当前 token 不会影响历史 token 的表示。唯一增加的只是当前新 token 的查询向量 $Q_(upright("new"))$ 与所有历史 $K$、$V$ 之间的交互。

KV Cache 正是利用这一性质：在生成每个新 token 时，只计算新 token 的 $Q$、$K$、$V$，将新 token 的 $K$、$V$ 追加到缓存中，然后用新 token 的 $Q$ 与缓存中全部历史 $K$ 计算注意力分数，最终从缓存的 $V$ 中加权聚合。这样，每步解码的计算量从 $O \( N^2 \)$ 降至 $O \( N \)$，总解码复杂度从 $O \( N^2 \)$ 降至 $O \( N^2 \)$ 中的常数因子大幅减小（约减少一半乘法运算）。

=== KV Cache 的实现
<kv-cache-的实现>
基于 #link(<sec-multi-head-attention>)[5.7] 节中的 #NormalTok("MultiHeadAttention");，我们在 #link("flash_att/kv_cache_module.py") 中实现了支持 KV Cache 的多头注意力模块 #NormalTok("MultiHeadAttentionKV");（继承自 #NormalTok("MultiHeadAttention");），以及配套的 #NormalTok("TransformerBlockKV"); 和 #NormalTok("TransformerModuleKV");。

#strong[MultiHeadAttentionKV 核心逻辑：]

#Skylighting(([#KeywordTok("class");#NormalTok(" MultiHeadAttentionKV(MultiHeadAttention):");],
[#NormalTok("    ");#CommentTok("\"\"\"MultiHeadAttention with KV cache support. Inherits all weights from parent.\"\"\"");],
[],
[#NormalTok("    ");#KeywordTok("def");#NormalTok(" forward(");#VariableTok("self");#NormalTok(", x, token_positions");#OperatorTok("=");#VariableTok("None");#NormalTok(", past_kv");#OperatorTok("=");#VariableTok("None");#NormalTok(", use_cache");#OperatorTok("=");#VariableTok("False");#NormalTok("):");],
[#NormalTok("        batch_size, seq_len, _ ");#OperatorTok("=");#NormalTok(" x.size()");],
[#NormalTok("        ");#CommentTok("# 计算当前步的 Q, K, V");],
[#NormalTok("        Q ");#OperatorTok("=");#NormalTok(" ");#VariableTok("self");#NormalTok(".W_q(x).view(batch_size, seq_len, ");#VariableTok("self");#NormalTok(".n_heads, ");#VariableTok("self");#NormalTok(".head_dim).transpose(");#DecValTok("1");#NormalTok(", ");#DecValTok("2");#NormalTok(")");],
[#NormalTok("        K_cur ");#OperatorTok("=");#NormalTok(" ");#VariableTok("self");#NormalTok(".W_k(x).view(batch_size, seq_len, ");#VariableTok("self");#NormalTok(".n_heads, ");#VariableTok("self");#NormalTok(".head_dim).transpose(");#DecValTok("1");#NormalTok(", ");#DecValTok("2");#NormalTok(")");],
[#NormalTok("        V_cur ");#OperatorTok("=");#NormalTok(" ");#VariableTok("self");#NormalTok(".W_v(x).view(batch_size, seq_len, ");#VariableTok("self");#NormalTok(".n_heads, ");#VariableTok("self");#NormalTok(".head_dim).transpose(");#DecValTok("1");#NormalTok(", ");#DecValTok("2");#NormalTok(")");],
[],
[#NormalTok("        ");#ControlFlowTok("if");#NormalTok(" token_positions ");#KeywordTok("is");#NormalTok(" ");#KeywordTok("not");#NormalTok(" ");#VariableTok("None");#NormalTok(":");],
[#NormalTok("            Q ");#OperatorTok("=");#NormalTok(" ");#VariableTok("self");#NormalTok(".rope(Q, token_positions)");],
[#NormalTok("            K_cur ");#OperatorTok("=");#NormalTok(" ");#VariableTok("self");#NormalTok(".rope(K_cur, token_positions)");],
[],
[#NormalTok("        ");#CommentTok("# 拼接历史 KV");],
[#NormalTok("        past_K ");#OperatorTok("=");#NormalTok(" past_V ");#OperatorTok("=");#NormalTok(" ");#VariableTok("None");],
[#NormalTok("        ");#ControlFlowTok("if");#NormalTok(" past_kv ");#KeywordTok("is");#NormalTok(" ");#KeywordTok("not");#NormalTok(" ");#VariableTok("None");#NormalTok(":");],
[#NormalTok("            past_K, past_V ");#OperatorTok("=");#NormalTok(" past_kv");],
[],
[#NormalTok("        ");#ControlFlowTok("if");#NormalTok(" past_K ");#KeywordTok("is");#NormalTok(" ");#KeywordTok("not");#NormalTok(" ");#VariableTok("None");#NormalTok(":");],
[#NormalTok("            K ");#OperatorTok("=");#NormalTok(" torch.cat([past_K, K_cur], dim");#OperatorTok("=");#DecValTok("2");#NormalTok(")   ");#CommentTok("# [B, H, past+cur, D]");],
[#NormalTok("            V ");#OperatorTok("=");#NormalTok(" torch.cat([past_V, V_cur], dim");#OperatorTok("=");#DecValTok("2");#NormalTok(")");],
[#NormalTok("        ");#ControlFlowTok("else");#NormalTok(":");],
[#NormalTok("            K, V ");#OperatorTok("=");#NormalTok(" K_cur, V_cur");],
[],
[#NormalTok("        present_kv ");#OperatorTok("=");#NormalTok(" (K, V) ");#ControlFlowTok("if");#NormalTok(" use_cache ");#ControlFlowTok("else");#NormalTok(" ");#VariableTok("None");],
[],
[#NormalTok("        ");#CommentTok("# Attention 计算（优先使用 flash_attn 的 kvcache API）");],
[#NormalTok("        ");#CommentTok("# ...");],
[#NormalTok("        ");#ControlFlowTok("return");#NormalTok(" output, present_kv");],));
#strong[KV Cache 推理函数]（#link("basics/inference/inference_kv.py")）：

#Skylighting(([#KeywordTok("def");#NormalTok(" decode_token_kv(input_tokens, model_kv, max_tokens_to_generate, top_p");#OperatorTok("=");#FloatTok("0.9");#NormalTok(", temperature");#OperatorTok("=");#FloatTok("1.0");#NormalTok("):");],
[#NormalTok("    model_kv.");#BuiltInTok("eval");#NormalTok("()");],
[#NormalTok("    input_tokens ");#OperatorTok("=");#NormalTok(" input_tokens.clone().detach().unsqueeze(");#DecValTok("0");#NormalTok(")");],
[#NormalTok("    past_kvs ");#OperatorTok("=");#NormalTok(" ");#VariableTok("None");],
[],
[#NormalTok("    ");#ControlFlowTok("with");#NormalTok(" torch.no_grad():");],
[#NormalTok("        ");#CommentTok("# Prefill: 处理完整 prompt，建立 KV cache");],
[#NormalTok("        logits, past_kvs ");#OperatorTok("=");#NormalTok(" model_kv(input_tokens, past_kvs");#OperatorTok("=");#NormalTok("past_kvs, use_cache");#OperatorTok("=");#VariableTok("True");#NormalTok(")");],
[],
[#NormalTok("        ");#ControlFlowTok("for");#NormalTok(" _ ");#KeywordTok("in");#NormalTok(" ");#BuiltInTok("range");#NormalTok("(max_tokens_to_generate):");],
[#NormalTok("            probabilities ");#OperatorTok("=");#NormalTok(" temperature_scaling(logits, temperature)");],
[#NormalTok("            next_token_idx ");#OperatorTok("=");#NormalTok(" top_p_sampling(probabilities, top_p)");],
[#NormalTok("            input_tokens ");#OperatorTok("=");#NormalTok(" torch.cat([input_tokens, next_token_idx], dim");#OperatorTok("=-");#DecValTok("1");#NormalTok(")");],
[],
[#NormalTok("            ");#CommentTok("# Decode: 仅将新 token 送入模型，复用缓存的 K/V");],
[#NormalTok("            logits, past_kvs ");#OperatorTok("=");#NormalTok(" model_kv(next_token_idx, past_kvs");#OperatorTok("=");#NormalTok("past_kvs, use_cache");#OperatorTok("=");#VariableTok("True");#NormalTok(")");],
[],
[#NormalTok("    ");#ControlFlowTok("return");#NormalTok(" input_tokens");],));
与无 KV Cache 的推理函数对比：标准推理每步将整个（不断增长的）序列重新输入模型 → 注意力每步从头计算 $O \( N^2 \)$；而 KV Cache 推理在 Prefill 后将每步输入缩减为单个 token → 注意力仅算新 token 对缓存的查询 $O \( N \)$。

=== 3. 实验结果
<实验结果>
为验证 KV Cache 的有效性，我们在 CPU 环境下设计了对照实验（代码见 #link("kvcache实验/") 目录）。实验使用相同的模型检查点（80M 参数，8 层，8 头），对 4 种 prompt 长度（10、100、1000、10000 tokens）各测试 10 条相同 prompt，每条生成 2 个新 token。对比方法为：

- #strong[无 KV Cache]：每步将完整序列送入 #NormalTok("TransformerModule");，注意力从头计算
- #strong[有 KV Cache]：Prefill 处理完整 prompt 后，每步仅送入 1 个新 token 至 #NormalTok("TransformerModuleKV");

两种方法固定相同的随机种子以确保可比性。#strong[加速比按 decode 阶段的 per-token 耗时计算]，排除 prefill 的干扰，直接反映每步生成新 token 的加速效果。

#strong[实验结果：]

#table(
  columns: (20%, 20%, 20%, 20%, 20%),
  align: (auto,auto,auto,auto,auto,),
  table.header([Prompt 长度], [Prefill 时间], [无 KV Cache decode 均值], [有 KV Cache decode 均值], [加速比],),
  table.hline(),
  [#strong[10]], [0.0222 ± 0.0019 s], [0.0219 ± 0.0018 s/token], [0.0172 ± 0.0020 s/token], [#strong[1.29 ×]],
  [#strong[100]], [0.0497 ± 0.0011 s], [0.0508 ± 0.0020 s/token], [0.0163 ± 0.0004 s/token], [#strong[3.13 ×]],
  [#strong[1000]], [0.3759 ± 0.0042 s], [0.3880 ± 0.0046 s/token], [0.0199 ± 0.0014 s/token], [#strong[19.59 ×]],
  [#strong[10000]], [22.6064 ± 0.3626 s], [22.8818 ± 0.3043 s/token], [0.0508 ± 0.0040 s/token], [#strong[452.80 ×]],
)
#strong[实验结果分析]

==== Prefill 阶段加速
<prefill-阶段加速>
#strong[Prefill 时间组成]

#table(
  columns: (24%, 24%, 28%, 24%),
  align: (auto,auto,auto,auto,),
  table.header([组件], [操作], [FLOPs], [备注],),
  table.hline(),
  [Embedding], [查表 $N arrow.r \[ N \, d \]$], [---], [可忽略],
  [QKVO 投影（$n_(upright("layers"))$ 层）], [$4 times$ MatMul $\[ N \, d \] times \[ d \, d \]$], [$8 n_(upright("layers")) N d^2$], [],
  [FFN（$n_(upright("layers"))$ 层）], [$3 times$ MatMul $\[ N \, d \] times \[ d \, d_(upright("ff")) \]$], [$6 n_(upright("layers")) N d d_(upright("ff"))$], [],
  [Attention $Q K^T$（$n_(upright("layers"))$ 层）], [MatMul $\[ N \, d_(upright("head")) \] times \[ d_(upright("head")) \, N \]$], [$2 n_(upright("layers")) N^2 d$], [平方项，长序列瓶颈],
  [Attention $upright("Score") #h(-1em) dot.op #h(-1em) V$（$n_(upright("layers"))$ 层）], [MatMul $\[ N \, N \] times \[ N \, d_(upright("head")) \]$], [$2 n_(upright("layers")) N^2 d$], [平方项，长序列瓶颈],
  [LM Head], [MatMul $\[ N \, d \] times \[ d \, V \]$], [$2 N d V$], [只执行一次],
  [采样], [Temperature + Top-P], [---], [可忽略],
)
#strong[瓶颈分析]

从实验数据验证了时间组成随序列长度 N 的迁移规律------L=10 → 100 增长约 2.2 倍（GPU kernel launch overhead 主导），L=100 → 1000 增长约 7.6 倍（$O \( N \)$ 线性投影项主导），L=1000 → 10000 增长约 60 倍（接近平方关系，$O \( N^2 \)$ 注意力项开始显著贡献）：

#table(
  columns: (33.33%, 33.33%, 33.33%),
  align: (auto,auto,auto,),
  table.header([序列长度], [主导开销], [瓶颈本质],),
  table.hline(),
  [短序列（N \< 100）], [GPU kernel launch + 内存带宽], [计算量小，硬件利用率低],
  [中等序列（100 \~ 2048）], [线性投影 QKVO + FFN（$O \( N dot.op d d_(upright("ff")) \)$）], [每层需做 7 次大矩阵乘法，计算密集],
  [长序列（N \> 2048）], [Attention $Q K^T$ + Score$dot.op V$（$O \( N^2 dot.op d \)$）], [注意力矩阵 $N times N$ 的计算与存储随 N 平方增长],
)
在本实验的 80M 参数小模型（d=768, d\_ff=2048, n\_layers=8）中，交叉点约在 N ≈ 2048 附近。当 N = 10000 时，$O \( N^2 \)$ 注意力项的计算量约占总 FLOPs 的 87%，成为绝对瓶颈，直接导致 Prefill 时间从 0.38s 飙升至 22.6s。所以加速 Prefill 的核心目标是削减 Attention 的 $O \( N^2 \)$ 计算量，并提升大矩阵乘法的硬件利用率。

#strong[Prefill 加速技术]

#table(
  columns: (33.33%, 33.33%, 33.33%),
  align: (auto,auto,auto,),
  table.header([方法], [原理], [论文],),
  table.hline(),
  [FlashAttention / FA2], [分块计算 + 在线 softmax，SRAM 内完成注意力。复杂度不变（仍 $O \( N^2 d \)$），但 HBM 读写从 $O \( N^2 \)$ 降至 $O \( N \)$，显存从 $O \( N^2 \)$ 降至 $O \( N \)$，实际加速 2--4×], [Dao et al., #emph[FlashAttention], NeurIPS 2022; Dao, #emph[FlashAttention-2], 2023],
  [稀疏 / 滑动窗口注意力], [限制每个 token 只关注局部窗口（大小 $w$）或稀疏模式（stride / global+local），复杂度从 $O \( N^2 d \)$ 降至 $O \( N w d \)$，$w lt.double N$，如 Sliding Window 取 $w = 4096$], [Beltagy et al., #emph[Longformer], 2020; Child et al., #emph[Sparse Transformer], NeurIPS 2019; Zaheer et al., #emph[BigBird], NeurIPS 2020],
  [低精度量化（FP8 / INT8）], [将激活/权重量化为 FP8 或 INT8，利用 GPU Tensor Core 提升吞吐量。FP8 相比 BF16 吞吐提升 2×，INT8 提升 4×；不改变复杂度，但降低单位运算开销], [Micikevicius et al., #emph[FP8 Formats for Deep Learning], 2022; Dettmers et al., #emph[LLM.int8()], NeurIPS 2022],
)
==== Decode 阶段加速
<decode-阶段加速>
#strong[Decode 时间组成（有 KV Cache）]

在 KV Cache 模式下，Decode 阶段每步只处理一个新 token（$N_(upright("new")) = 1$）：

#table(
  columns: (16.67%, 16.67%, 22.22%, 44.44%),
  align: (auto,auto,auto,auto,),
  table.header([模块], [操作], [复杂度], [计算量（FLOPs）],),
  table.hline(),
  [QKVO 投影], [$4 times$ MatMul $\[ 1 \, d \] times \[ d \, d \]$], [$O \( d^2 \)$], [$8 d^2$],
  [FFN（gate + up + down）], [$3 times$ MatMul $\[ 1 \, d \] times \[ d \, d_(upright("ff")) \]$], [$O \( d dot.op d_(upright("ff")) \)$], [$6 d d_(upright("ff"))$],
  [Attention $Q K^T$], [MatMul $\[ 1 \, d_(upright("head")) \] times \[ d_(upright("head")) \, N \]$], [$O \( N dot.op d \)$], [$2 N d$],
  [Attention $upright("score") dot.op V$], [MatMul $\[ 1 \, N \] times \[ N \, d_(upright("head")) \]$], [$O \( N dot.op d \)$], [$2 N d$],
)
#strong[瓶颈分析]

Decode 的核心问题不是计算量，而是#strong[内存带宽瓶颈]。每生成一个 token：

+ #strong[加载模型权重]：80M 参数 × 2 bytes（bf16）= 约 160 MB，每步都需要完整遍历一次
+ #strong[读取 KV Cache]：$2 times n_(upright("layers")) times n_(upright("heads")) times N times d_(upright("head"))$ 个元素。当 N=10000 时，KV Cache 约 $2 times 8 times 8 times 10000 times 96 times 2$ bytes ≈ 246 MB，且随 N 线性增长
+ #strong[计算密度极低]：每个参数每步仅参与一次乘加运算（arithmetic intensity ≈ 1-2 FLOPs/byte），远低于 GPU 的计算峰值（约 300+ FLOPs/byte 的硬件能力），Decode 完全受限于 HBM 带宽

#table(
  columns: (13.64%, 43.18%, 43.18%),
  align: (auto,auto,auto,),
  table.header([因素], [无 KV Cache Decode], [有 KV Cache Decode],),
  table.hline(),
  [每步计算量], [$O \( N dot.op d^2 + N^2 dot.op d \)$], [$O \( d^2 + N dot.op d \)$],
  [硬件瓶颈], [计算受限（compute-bound）], [内存带宽受限（memory-bound）],
  [BLAS 效率], [高（GEMM, $\[ N \, d \] times \[ d \, d \]$）], [低（GEMV, $\[ 1 \, d \] times \[ d \, d \]$）],
  [每步加载模型权重], [一次], [一次（相同）],
  [每步加载 KV Cache], [无（重新计算）], [全量历史 K/V],
)
#strong[Decode 加速技术（经典论文）]

#table(
  columns: (17.14%, 31.43%, 25.71%, 25.71%),
  align: (auto,auto,auto,auto,),
  table.header([技术], [针对的瓶颈], [核心思想], [代表论文],),
  table.hline(),
  [#strong[Multi-Query / Grouped-Query Attention]], [KV Cache 体积], [减少 K, V 的 head 数量，MQA 压缩 $n_(upright("heads"))$ 倍，GQA 压缩 $n_(upright("heads")) \/ n_(upright("groups"))$ 倍，直接减少 KV Cache 读取带宽需求], [Shazeer, 2019; Ainslie et al., 2023],
  [#strong[KV Cache 量化]], [KV Cache 内存占用与带宽], [将 FP16 K/V 量化为 INT4/INT8 甚至 INT2，以微小精度损失换取 4-8× 的 Cache 压缩比，降低内存访问压力], [Sheng et al., 2023; Liu et al., 2024; Hooper et al., 2024],
  [#strong[PagedAttention (vLLM)]], [KV Cache 显存碎片与利用率], [借鉴操作系统分页机制，将 KV Cache 划分为固定大小的 Page，按需分配、动态回收，近消除碎片，提升 batch 推理吞吐], [Kwon et al., 2023],
  [#strong[Speculative Decoding]], [Decode 串行依赖（每步 1 token）], [用小草稿模型快速生成 k 个候选 token，再用大模型一次 forward 并行验证，接受匹配前缀，实现每步生成多 token 而不损质量], [Leviathan et al., 2023; Chen et al., 2023],
)
== 9.3 FlashAttention-2
<flashattention-2>
FlashAttention-2 是 FlashAttention 的改进版本，其核心思想是通过#strong[分块（Tiling）计算]将注意力计算从高带宽内存（HBM）移至片上 SRAM 中完成，避免在 HBM 中物化完整的 $N times N$ 注意力矩阵。标准注意力需将 $Q K^T$ 的完整结果写回 HBM 再读回做 softmax，当序列长度 $N$ 较大时，这一读写带来的内存带宽瓶颈远超过计算本身。FlashAttention 通过在线 safe softmax 算法将 softmax 分解为可合并的分块统计量，使得每个块仅在 SRAM 中完成”读取→计算→写回”循环，核心优化点包括： (1) 减少 HBM 访问次数------将中间注意力矩阵留存在 SRAM；(2) 在线更新 softmax 归一化因子，无需全局同步；(3) 反向传播时通过重计算（recomputation）代替存储中间激活，将显存开销从 $O \( N^2 \)$ 降为 $O \( N \)$。

FlashAttention-2 在第一代基础上进一步优化：(1) 将外层循环从 batch/head 维度移至序列长度维度，提高 GPU 并行度；(2) 减少非矩阵乘法运算（non-matmul FLOPs）占比；(3) 优化 warp 间的工作划分以适配新的 GPU 架构。

#strong[预期效果]：相比标准注意力，训练和推理速度提升 2--4 倍，显存占用从 $O \( N^2 \)$ 降至 $O \( N \)$，使更长上下文窗口（如 32K、128K tokens）的训练在单 GPU 上变得可行。

#strong[本模型实测结果（80M 参数，单 GPU）：]

#table(
  columns: 3,
  align: (auto,auto,auto,),
  table.header([配置], [训练时间], [显存占用],),
  table.hline(),
  [标准注意力（无 FlashAttention）], [约 6 小时], [约 24 GB],
  [启用 FlashAttention-2], [约 4 小时], [约 18 GB],
  [#strong[改善幅度]], [#strong[\-33%]], [#strong[\-25%]],
)
由此可见，FlashAttention-2 在本项目小规模模型上依然带来了可观的加速与显存节省，验证了其减少 HBM 访问和中间激活存储的核心收益。

= 10 建议
<建议>
== 优先阅读代码而非训练实操
<优先阅读代码而非训练实操>
如果你想要学习大模型的预训练，我们推荐你去看模型和训练部分的代码，而不是投入大量时间进行训练实操。

原因有三：其一，80M 的模型参数量太小，模型最终效果有限，生成质量与真正的大模型相去甚远；其二，80M 规模的预训练耗时并不短（本项目在单张 4090 上仍需约 6 小时），但换来的体验却非常有限；其三，也是最重要的一点------80M 大小的预训练#strong[无法让你体验到现代大模型训练过程中的各种优化技术和实际挑战]。

=== 代码测试非常重要
<代码测试非常重要>
本项目中我们踩过两个印象深刻的 bug，都是因为缺少充分的单元测试导致的，浪费了大量训练时间：

#strong[Bug 1：TransformerBlock 忘记继承 #NormalTok("nn.Module");。] 在模型搭建部分，#NormalTok("transformer_block"); 类忘记写 #NormalTok("(nn.Module)"); 继承。这导致该类的所有 #NormalTok("nn.Parameter"); 和子模块（RMSNorm、MultiHeadAttention、SwiGLU）无法被 PyTorch 的 #NormalTok("model.parameters()"); 自动发现------这些参数在优化器中”不存在”，#strong[完全不参与训练]。损失只能降到 5 左右就再也下不去了（正常的训练损失应当降到 3.5 左右），我们排查了很久才发现是继承缺失的问题。加上 #NormalTok("nn.Module"); 继承后，损失立刻正常下降。

#strong[Bug 2：Tokenizer 忘记加入特殊符号。] 在 BPE 训练和编码阶段，我们忘记将 #NormalTok(">"); 等特殊符号加入数据预处理流程。结果是------模型训练完成后虽然能生成通顺的文本，但#strong[无法输出终止符号]，只能靠我们手动设置的最大长度来截断生成。生成内容往往会一直絮叨下去，直到达到 #NormalTok("max_tokens"); 上限。这个 bug 的修复只需要在编码数据时确保特殊 token 被正确加入词表和训练数据中，但因为没有在 tokenizer 层面写测试，直到推理阶段才发现问题.

这两个 bug 的教训是：#strong[每个模块写完之后一定要写测试]。Tokenizer 的测试（编码-解码一致性、特殊 token 处理）、模型的测试（参数可训练性验证、前向-反向完整性检查、梯度流动检查）都应该在开始正式训练之前完成。花 30 分钟写测试，可能省下 6 小时的无效训练。

== 10.3 一定要看数据集内容！！！
<一定要看数据集内容>
== 10.4 参数初始化对本实验影响不大
<参数初始化对本实验影响不大>
我们在这个项目中对参数初始化做了详细的调研和自定义实现（见 #link(<sec-param-init>)[5.1 节]），使用了截断正态分布、精心选择了 $sigma = 0.02$ 等参数。但实验结果表明：在本项目的规模（80M 参数、1 个 epoch、14.58 亿 token）下，#strong[参数初始化对最终训练结果几乎没有影响]。

无论是 Xavier 初始化、He 初始化、还是我们的截断正态分布，只要初始化的方差不过大（不导致梯度爆炸）或过小（不导致梯度消失），模型都能在几百步内迅速调整到相近的损失水平。这是因为：

- 80M 参数模型的优化空间相对简单，优化器（AdamW）能够在足够多的训练步数内补偿初始化的差异
- 14.58 亿 token 的训练量足以让模型”忘记”初始化的影响
- Pre-Norm 架构本身就降低了对初始化的敏感度

参数初始化真正变得关键是在#strong[更大规模模型]（1B+ 参数）和#strong[更深网络]（48+ 层）上，那时不当的初始化会导致训练前期梯度爆炸或梯度消失，直接导致训练失败。但对于本项目这种小规模实验，初始化的重要性被高估了------#strong[把时间花在检查数据和写测试上，性价比远高于调初始化参数].

数据集 数据量多少？ pertaring效果 知识储备 续写能力 损失函数 2以下
