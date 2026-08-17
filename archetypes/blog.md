---
title: "{{ replace .File.ContentBaseName "-" " " | title }}"
date: {{ .Date }}
description: ""
draft: true
math: false
# Cite these in the body with {{`{{< cite some-key >}}`}}. Numbering follows the
# order below, and an unknown key fails the build rather than shipping a dead link.
# references:
#   - key: some-key
#     author: "Lastname, F."
#     year: 2024
#     title: "Title of the thing"
#     container: "Journal or Publisher"
#     url: "https://example.com"
---
