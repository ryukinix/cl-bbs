// Common Lisp Snippet Executor and Playground using JSCL
// Loaded dynamically and runs completely client-side.

let jsclLoading = false;
let jsclLoaded = false;
const jsclCallbacks = [];

function ensureJSCL(callback) {
  if (window.jscl) {
    callback();
    return;
  }
  jsclCallbacks.push(callback);
  if (jsclLoading) return;
  jsclLoading = true;

  const script = document.createElement('script');
  script.src = "https://cdn.jsdelivr.net/gh/jscl-project/jscl-project.github.io/jscl.js";
  script.onload = () => {
    jsclLoaded = true;
    while (jsclCallbacks.length > 0) {
      const cb = jsclCallbacks.shift();
      cb();
    }
  };
  script.onerror = () => {
    // Try unpkg as a fallback CDN
    const fallbackScript = document.createElement('script');
    fallbackScript.src = "https://unpkg.com/jscl/dist/jscl.js";
    fallbackScript.onload = () => {
      jsclLoaded = true;
      while (jsclCallbacks.length > 0) {
        const cb = jsclCallbacks.shift();
        cb();
      }
    };
    fallbackScript.onerror = (err) => {
      console.error("Failed to load JSCL from both CDNs:", err);
      alert("Failed to load JSCL Common Lisp compiler. Please check your internet connection.");
    };
    document.head.appendChild(fallbackScript);
  };
  document.head.appendChild(script);
}

function initInlineSnippets() {
  const blocks = document.querySelectorAll('pre.lisp-code-block:not(#playground-editor)');
  blocks.forEach((block) => {
    // Wrap the pre element
    const container = document.createElement('div');
    container.className = 'lisp-snippet-container';
    container.style.margin = '1em 0';

    block.parentNode.insertBefore(container, block);
    container.appendChild(block);

    // Create controls
    const controls = document.createElement('div');
    controls.className = 'lisp-snippet-controls';
    controls.style.margin = '5px 0';
    controls.style.display = 'flex';
    controls.style.gap = '10px';

    const runBtn = document.createElement('button');
    runBtn.textContent = 'Run';
    runBtn.className = 'lisp-btn lisp-btn-run';

    const editBtn = document.createElement('button');
    editBtn.textContent = 'Edit';
    editBtn.className = 'lisp-btn lisp-btn-edit';

    controls.appendChild(runBtn);
    controls.appendChild(editBtn);
    container.appendChild(controls);

    // Create output panel
    const outputPanel = document.createElement('pre');
    outputPanel.className = 'lisp-output-panel';
    outputPanel.style.display = 'none';
    outputPanel.style.padding = '0.5em';
    outputPanel.style.marginTop = '5px';
    outputPanel.style.border = '1px dashed currentColor';
    outputPanel.style.backgroundColor = 'rgba(128, 128, 128, 0.05)';
    outputPanel.style.whiteSpace = 'pre-wrap';
    outputPanel.style.wordBreak = 'break-all';
    container.appendChild(outputPanel);

    let isEditing = false;

    editBtn.addEventListener('click', () => {
      if (!isEditing) {
        block.contentEditable = 'true';
        block.spellcheck = false;
        block.style.outline = '1px solid currentColor';
        block.style.padding = '5px';
        block.focus();
        editBtn.textContent = 'View';
        isEditing = true;
      } else {
        block.contentEditable = 'false';
        block.style.outline = 'none';
        block.style.padding = '';
        editBtn.textContent = 'Edit';
        isEditing = false;

        // Fetch colorized version from backend API
        const code = block.textContent;
        fetch('/api/colorize', {
          method: 'POST',
          headers: {
            'Content-Type': 'application/x-www-form-urlencoded'
          },
          body: 'code=' + encodeURIComponent(code)
        })
        .then(response => response.text())
        .then(html => {
          block.innerHTML = html;
        })
        .catch(err => console.error("Failed to colorize snippet:", err));
      }
    });

    block.addEventListener('keydown', (e) => {
      if (e.ctrlKey && e.key === 'Enter') {
        e.preventDefault();
        runBtn.click();
      }
    });

    runBtn.addEventListener('click', () => {
      runBtn.disabled = true;
      const originalText = runBtn.textContent;
      runBtn.textContent = 'Running...';
      outputPanel.style.display = 'block';
      outputPanel.textContent = 'Initializing JSCL and executing...';

      ensureJSCL(() => {
        try {
          const code = block.textContent;
          const wrappedCode = `
(let ((out (make-string-output-stream)))
  (let ((*standard-output* out))
    (let ((val (progn
${code}
    )))
      (format nil "~A|==SEPARATOR==|~S" (get-output-stream-string out) val))))
`;
          const resRaw = window.jscl.evaluateString(wrappedCode);
          let resStr = resRaw;
          if (Array.isArray(resRaw)) {
            resStr = resRaw.join('');
          } else if (typeof resRaw !== 'string') {
            resStr = String(resRaw);
          }

          let stdout = "";
          let returnValue = "";
          if (typeof resStr === 'string' && resStr.includes('|==SEPARATOR==|')) {
            const parts = resStr.split('|==SEPARATOR==|');
            stdout = parts[0];
            returnValue = parts[1];
          } else {
            returnValue = String(resStr);
          }

          let displayResult = "";
          if (stdout) {
            displayResult += stdout;
            if (!stdout.endsWith('\n')) {
              displayResult += '\n';
            }
          }
          displayResult += `=> ${returnValue}`;

          outputPanel.textContent = displayResult;
          outputPanel.style.color = '';
        } catch (err) {
          outputPanel.textContent = `Error: ${err.message || err}`;
          outputPanel.style.color = 'red';
        } finally {
          runBtn.disabled = false;
          runBtn.textContent = originalText;
        }
      });
    });
  });
}

function initPlayground() {
  const editor = document.getElementById('playground-editor');
  const runBtn = document.getElementById('playground-run');
  const clearBtn = document.getElementById('playground-clear');
  const examplesSelect = document.getElementById('playground-examples');
  const outputPanel = document.getElementById('playground-output');

  if (!editor || !runBtn || !clearBtn || !examplesSelect || !outputPanel) return;

  const examples = {
    hello: `(format t "Hello, World!~%")`,
    fib: `(defun fib (n)
  (if (< n 2)
      n
      (+ (fib (- n 1)) (fib (- n 2)))))

(format t "Fibonacci of 10 is: ~a~%" (fib 10))`,
    loop: `(loop for x from 1 to 5
      do (format t "Square of ~d is ~d~%" x (* x x)))`,
    clos: `(defclass person ()
  ((name :accessor person-name :initarg :name)
   (age :accessor person-age :initarg :age)))

(defmethod introduce ((p person))
  (format t "Hi, I am ~a and I am ~a years old.~%"
          (person-name p)
          (person-age p)))

(let ((p (make-instance 'person :name "Alice" :age 30)))
  (introduce p))`
  };

  examplesSelect.addEventListener('change', () => {
    const key = examplesSelect.value;
    const exampleData = document.getElementById('example-data-' + key);
    if (exampleData) {
      editor.innerHTML = exampleData.innerHTML;
    } else {
      editor.innerHTML = "";
    }
  });

  clearBtn.addEventListener('click', () => {
    outputPanel.textContent = '';
    outputPanel.style.display = 'none';
  });

  editor.addEventListener('keydown', (e) => {
    if (e.ctrlKey && e.key === 'Enter') {
      e.preventDefault();
      runBtn.click();
    }
  });

  runBtn.addEventListener('click', () => {
    runBtn.disabled = true;
    const originalText = runBtn.textContent;
    runBtn.textContent = 'Running...';
    outputPanel.style.display = 'block';
    outputPanel.textContent = 'Initializing JSCL and executing...';

    ensureJSCL(() => {
      try {
        const code = editor.textContent;
        const wrappedCode = `
(let ((out (make-string-output-stream)))
  (let ((*standard-output* out))
    (let ((val (progn
${code}
    )))
      (format nil "~A|==SEPARATOR==|~S" (get-output-stream-string out) val))))
`;
        const resRaw = window.jscl.evaluateString(wrappedCode);
        let resStr = resRaw;
        if (Array.isArray(resRaw)) {
          resStr = resRaw.join('');
        } else if (typeof resRaw !== 'string') {
          resStr = String(resRaw);
        }

        let stdout = "";
        let returnValue = "";
        if (typeof resStr === 'string' && resStr.includes('|==SEPARATOR==|')) {
          const parts = resStr.split('|==SEPARATOR==|');
          stdout = parts[0];
          returnValue = parts[1];
        } else {
          returnValue = String(resStr);
        }

        let displayResult = "";
        if (stdout) {
          displayResult += stdout;
          if (!stdout.endsWith('\n')) {
            displayResult += '\n';
          }
        }
        displayResult += `=> ${returnValue}`;

        outputPanel.textContent = displayResult;
        outputPanel.style.color = '';

        // Dynamically update the editor syntax highlighting using backend colorize API
        fetch('/api/colorize', {
          method: 'POST',
          headers: {
            'Content-Type': 'application/x-www-form-urlencoded'
          },
          body: 'code=' + encodeURIComponent(code)
        })
        .then(response => response.text())
        .then(html => {
          editor.innerHTML = html;
        })
        .catch(err => console.error("Failed to colorize playground code:", err));

      } catch (err) {
        outputPanel.textContent = `Error: ${err.message || err}`;
        outputPanel.style.color = 'red';
      } finally {
        runBtn.disabled = false;
        runBtn.textContent = originalText;
      }
    });
  });
}

document.addEventListener('DOMContentLoaded', () => {
  initInlineSnippets();
  initPlayground();
});
