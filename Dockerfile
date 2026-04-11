# ==============================================================================
# nvim-voom test image
# ==============================================================================
# Provides a hermetic Neovim environment with all tree-sitter parsers needed
# by the test suite. Contributors run `mise run test-docker` — no local
# parser installation required.
#
# Multi-stage build:
#   1. build  — compiles the markdown/markdown_inline parsers (the only ones
#               not available as Alpine packages)
#   2. runtime — minimal image with Neovim, pre-compiled parsers, and mini.nvim

# ------------------------------------------------------------------------------
# Stage 1: build the markdown parsers from source
# ------------------------------------------------------------------------------
# Alpine packages cover every parser we need except markdown and
# markdown_inline. We compile those here using the tree-sitter CLI,
# targeting the ABI version that matches Neovim's bundled tree-sitter
# runtime (ABI 14 for Neovim 0.10.x).

FROM alpine:3.21 AS build

RUN apk add --no-cache \
      tree-sitter-cli \
      git gcc musl-dev nodejs

RUN git clone --depth 1 \
      https://github.com/tree-sitter-grammars/tree-sitter-markdown.git \
      /tmp/tree-sitter-markdown

WORKDIR /tmp/tree-sitter-markdown/tree-sitter-markdown
RUN tree-sitter generate --abi 14 src/grammar.json 2>/dev/null || true \
 && tree-sitter build -o /tmp/markdown.so

WORKDIR /tmp/tree-sitter-markdown/tree-sitter-markdown-inline
RUN tree-sitter generate --abi 14 src/grammar.json 2>/dev/null || true \
 && tree-sitter build -o /tmp/markdown_inline.so

# Pre-clone mini.nvim so the test harness never hits the network.
RUN git clone --depth 1 --filter=blob:none \
      https://github.com/echasnovski/mini.nvim \
      /tmp/mini.nvim

# ------------------------------------------------------------------------------
# Stage 2: runtime image
# ------------------------------------------------------------------------------
FROM alpine:3.21

RUN apk add --no-cache \
      neovim \
      tree-sitter-grammars \
      git

# Install the markdown parsers built in stage 1.
COPY --from=build /tmp/markdown.so        /usr/share/nvim/runtime/parser/markdown.so
COPY --from=build /tmp/markdown_inline.so /usr/share/nvim/runtime/parser/markdown_inline.so

# Pre-install mini.nvim so minimal_init.lua skips the git clone.
COPY --from=build /tmp/mini.nvim /root/.local/share/nvim/site/pack/deps/start/mini.nvim
