import Foundation

enum EmbeddedTemplate {
    static let defaultName = "caption-top"

    static let captionTop = #"""
    <!doctype html><html><head><meta charset="utf-8"><style>
    {{FONT_FACES}}
    *{margin:0;padding:0;box-sizing:border-box}
    html,body{width:{{W}}px;height:{{H}}px;overflow:hidden}
    .stage{position:relative;width:{{W}}px;height:{{H}}px;overflow:hidden}
    .bg{position:absolute;inset:0;width:{{W}}px;height:{{H}}px;object-fit:cover;display:block}
    .caption{position:absolute;top:{{THEME.captionTop}};left:0;width:{{W}}px;padding:{{THEME.captionPadding}};text-align:center;font-family:{{FONT_STACK}};font-weight:{{THEME.captionWeight}};font-size:{{THEME.captionSize}};line-height:{{THEME.captionLineHeight}};letter-spacing:{{THEME.captionLetterSpacing}};color:{{THEME.headlineColor}}}
    .caption .accent{color:{{THEME.accent}}}
    .caption .subtitle{margin-top:28px;font-size:{{THEME.subtitleSize}};font-weight:{{THEME.subtitleWeight}};line-height:1.3;letter-spacing:-0.01em;color:{{THEME.subtitleColor}}}
    .caption .subtitle:empty{display:none}
    .device{position:absolute;width:{{DEV_W}}px;height:{{DEV_H}}px;top:{{DEV_TOP}}px;left:{{DEV_LEFT}}px;transform:rotate({{TILT}}deg);filter:drop-shadow({{THEME.deviceShadow}})}
    .device .screen{position:absolute;left:0;top:0;width:{{DEV_W}}px;height:{{DEV_H}}px;-webkit-mask:url('{{MASK}}') center/100% 100% no-repeat;mask:url('{{MASK}}') center/100% 100% no-repeat}
    .device .screen img{position:absolute;left:{{SX}}px;top:{{SY}}px;width:{{SW}}px;height:{{SH}}px;object-fit:cover;display:block}
    .device .frame{position:absolute;left:0;top:0;width:{{DEV_W}}px;height:{{DEV_H}}px;display:block}
    </style></head><body>
    <div class="stage">
      <img class="bg" src="{{BG_IMG}}">
      <div class="caption">{{cap.title}}<div class="subtitle">{{cap.subtitle}}</div></div>
      <div class="device">
        <div class="screen"><img src="{{SCREEN}}"></div>
        <img class="frame" src="{{FRAME}}">
      </div>
    </div>
    <script>
    addEventListener('load', () => document.fonts.ready.then(() => {
      if ('{{THEME.captionFit}}' !== 'shrink') return;
      const caption = document.querySelector('.caption');
      const subtitle = caption.querySelector('.subtitle');
      const deviceBox = document.querySelector('.device').getBoundingClientRect();
      const gap = parseFloat('{{THEME.captionFitGap}}');
      const minPercent = parseFloat('{{THEME.captionMinScale}}');
      const titleSize = parseFloat(getComputedStyle(caption).fontSize);
      const subtitleSize = parseFloat(getComputedStyle(subtitle).fontSize);
      const subtitleSpacing = parseFloat(getComputedStyle(subtitle).marginTop);
      const captionText = document.createRange();
      captionText.selectNodeContents(caption);
      const clearsDevice = () => {
        const textBox = captionText.getBoundingClientRect();
        return textBox.bottom + gap <= deviceBox.top || textBox.top - gap >= deviceBox.bottom;
      };
      const scaleCaption = percent => {
        caption.style.fontSize = titleSize * percent / 100 + 'px';
        subtitle.style.fontSize = subtitleSize * percent / 100 + 'px';
        subtitle.style.marginTop = subtitleSpacing * percent / 100 + 'px';
      };
      let outcome = '100';
      if (!clearsDevice()) {
        scaleCaption(minPercent);
        if (clearsDevice()) {
          let fittingPercent = minPercent, overlappingPercent = 100;
          while (overlappingPercent - fittingPercent > 1) {
            const middlePercent = Math.floor((fittingPercent + overlappingPercent) / 2);
            scaleCaption(middlePercent);
            if (clearsDevice()) fittingPercent = middlePercent; else overlappingPercent = middlePercent;
          }
          scaleCaption(fittingPercent);
          outcome = String(fittingPercent);
        } else {
          outcome = 'overlaps';
        }
      }
      document.body.dataset.captionFit = outcome;
    }));
    </script>
    </body></html>
    """#

    static let captionBottom = #"""
    <!doctype html><html><head><meta charset="utf-8"><style>
    {{FONT_FACES}}
    *{margin:0;padding:0;box-sizing:border-box}
    html,body{width:{{W}}px;height:{{H}}px;overflow:hidden}
    .stage{position:relative;width:{{W}}px;height:{{H}}px;overflow:hidden}
    .bg{position:absolute;inset:0;width:{{W}}px;height:{{H}}px;object-fit:cover;display:block}
    .caption{position:absolute;bottom:{{THEME.captionBottom}};left:0;width:{{W}}px;padding:{{THEME.captionPadding}};text-align:center;font-family:{{FONT_STACK}};font-weight:{{THEME.captionWeight}};font-size:{{THEME.captionSize}};line-height:{{THEME.captionLineHeight}};letter-spacing:{{THEME.captionLetterSpacing}};color:{{THEME.headlineColor}}}
    .caption .accent{color:{{THEME.accent}}}
    .caption .subtitle{margin-top:28px;font-size:{{THEME.subtitleSize}};font-weight:{{THEME.subtitleWeight}};line-height:1.3;letter-spacing:-0.01em;color:{{THEME.subtitleColor}}}
    .caption .subtitle:empty{display:none}
    .device{position:absolute;width:{{DEV_W}}px;height:{{DEV_H}}px;top:{{DEV_TOP}}px;left:{{DEV_LEFT}}px;transform:rotate({{TILT}}deg);filter:drop-shadow({{THEME.deviceShadow}})}
    .device .screen{position:absolute;left:0;top:0;width:{{DEV_W}}px;height:{{DEV_H}}px;-webkit-mask:url('{{MASK}}') center/100% 100% no-repeat;mask:url('{{MASK}}') center/100% 100% no-repeat}
    .device .screen img{position:absolute;left:{{SX}}px;top:{{SY}}px;width:{{SW}}px;height:{{SH}}px;object-fit:cover;display:block}
    .device .frame{position:absolute;left:0;top:0;width:{{DEV_W}}px;height:{{DEV_H}}px;display:block}
    </style></head><body>
    <div class="stage">
      <img class="bg" src="{{BG_IMG}}">
      <div class="device">
        <div class="screen"><img src="{{SCREEN}}"></div>
        <img class="frame" src="{{FRAME}}">
      </div>
      <div class="caption">{{cap.title}}<div class="subtitle">{{cap.subtitle}}</div></div>
    </div>
    <script>
    addEventListener('load', () => document.fonts.ready.then(() => {
      if ('{{THEME.captionFit}}' !== 'shrink') return;
      const caption = document.querySelector('.caption');
      const subtitle = caption.querySelector('.subtitle');
      const deviceBox = document.querySelector('.device').getBoundingClientRect();
      const gap = parseFloat('{{THEME.captionFitGap}}');
      const minPercent = parseFloat('{{THEME.captionMinScale}}');
      const titleSize = parseFloat(getComputedStyle(caption).fontSize);
      const subtitleSize = parseFloat(getComputedStyle(subtitle).fontSize);
      const subtitleSpacing = parseFloat(getComputedStyle(subtitle).marginTop);
      const captionText = document.createRange();
      captionText.selectNodeContents(caption);
      const clearsDevice = () => {
        const textBox = captionText.getBoundingClientRect();
        return textBox.bottom + gap <= deviceBox.top || textBox.top - gap >= deviceBox.bottom;
      };
      const scaleCaption = percent => {
        caption.style.fontSize = titleSize * percent / 100 + 'px';
        subtitle.style.fontSize = subtitleSize * percent / 100 + 'px';
        subtitle.style.marginTop = subtitleSpacing * percent / 100 + 'px';
      };
      let outcome = '100';
      if (!clearsDevice()) {
        scaleCaption(minPercent);
        if (clearsDevice()) {
          let fittingPercent = minPercent, overlappingPercent = 100;
          while (overlappingPercent - fittingPercent > 1) {
            const middlePercent = Math.floor((fittingPercent + overlappingPercent) / 2);
            scaleCaption(middlePercent);
            if (clearsDevice()) fittingPercent = middlePercent; else overlappingPercent = middlePercent;
          }
          scaleCaption(fittingPercent);
          outcome = String(fittingPercent);
        } else {
          outcome = 'overlaps';
        }
      }
      document.body.dataset.captionFit = outcome;
    }));
    </script>
    </body></html>
    """#

    static func bootstrap(root: String) throws {
        let templatesDir = join(root, "templates")
        for (name, contents) in [("caption-top", captionTop), ("caption-bottom", captionBottom)] {
            let path = join(templatesDir, "\(name).html")
            guard !FileManager.default.fileExists(atPath: path) else { continue }
            try FileManager.default.ensureDirectory(templatesDir)
            try (contents + "\n").write(toFile: path, atomically: true, encoding: .utf8)
            print("  ✓ templates/\(name).html (bootstrapped)")
        }
    }
}
