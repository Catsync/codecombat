RootView = require 'views/core/RootView'
template = require 'templates/artisans/student-solutions-view'

Campaigns = require 'collections/Campaigns'
Campaign = require 'models/Campaign'

Levels = require 'collections/Levels'
Level = require 'models/Level'
unless typeof esper is 'undefined'
  parser = new esper().realm.parser

HEX_CHARS = '0123456789abcdef'.split('')
EXTRA = [
  -2147483648
  8388608
  32768
  128
]
SHIFT = [
  24
  16
  8
  0
]
blocks = []

module.exports = class StudentSolutionsView extends RootView
  template: template
  id: 'student-solutions-view'
  events:
    'click #overview-button': 'onOverviewButtonClicked'
    'click #intro-button': 'onIntroButtonClicked'

  levelSlug: 'eagle-eye'
  limit: 100
  sessions: []
  solutions: {}
  count: {}
  errors: 0

  initialize: () ->
    @getRecentSessions (sessions) =>
      @sessions = sessions
      for session in sessions
        lang = session.codeLanguage
        continue unless lang is 'javascript'
        src = session.code?['hero-placeholder'].plan
        ast = null
        try
          ast = parser(src)
        catch e
          # console.log "Skipping due to error"
          @errors += 1
          continue
        # console.log "parsed"
        # console.log src

        ast = @processASTNode(ast)
        hash = @sha1(JSON.stringify(ast))
        # Count how many solutions match this hash
        @count[hash] ?= 0
        @count[hash] += 1
        # Store sessions by hash key
        @solutions[hash] ?= []
        @solutions[hash].push session

      # console.log "count"
      # console.log @count
      console.log "solutions"
      console.log @solutions
      # for hash, num  of @count
      #   continue unless num > 1
      #   console.log "matches"
      #   console.log script for script in @solutions[hash]


      tallyFn = (result, value, key) =>
        return result if value is 1
        result[value] ?= []
        result[value].push key
        # result[value].hash = key
        # for session in @solutions[key]
        #   # result[value].sessions.push session
        #   result[value].complete += 1 if session.state.complete
        result

      @talliedHashes = _.reduce(@count, tallyFn, {})
      console.log "tally"
      console.log @talliedHashes

      @sortedTallyCounts = _.sortBy(_.keys(@talliedHashes)).reverse()
      console.log "sorted"
      console.log @sortedTallyCounts

  # TODO: refactor this out somewhere from here and CampaignLevelView.coffee
  getRecentSessions: (doneCallback) ->
    success = (data) =>
      return doneCallback(data) if @destroyed
      # console.log 'getRecentSessions', data
      # @sessions = data
      doneCallback(data)
    request = @supermodel.addRequestResource 'level_sessions_recent', {
      url: "/db/level.session/-/recent"
      data: {slug: @levelSlug, limit: @limit}
      method: 'POST'
      success: success
    }, 0
    request.load()


  processASTNode: (node, d=0) =>
    return unless node?
    # console.log "processing", d
    delete node.range if node.range
    delete node. loc if node.loc
    # console.log node

    switch node.type
      when "Program", "BlockStatement"
        @processASTNode(n,d+1) for n in node.body
      when "FunctionDeclaration"
        @processASTNode(node.body, d+1)
      when "ExpressionStatement"
        @processASTNode(node.expression)
      when "CallExpression"
        @processASTNode(node.callee)
      when "WhileStatement"
        @processASTNode(node.test, d+1)
        @processASTNode(node.body, d+1)
      when "ForStatement"
        @processASTNode(node.init, d+1)
        @processASTNode(node.test, d+1)
        @processASTNode(node.update, d+1)
        @processASTNode(node.body, d+1)
      when "IfStatement"
        @processASTNode(node.test, d+1)
        @processASTNode(node.consequent, d+1)
        @processASTNode(node.alternate, d+1)
      when "BinaryExpression","LogicalExpression"
        @processASTNode(node.left, d+1)
        @processASTNode(node.right, d+1)
      when "AssignmentExpression"
        @processASTNode(node.right, d+1)
      when "VariableDeclaration"
        @processASTNode(n, d+1) for n in node.declarations
      when "VariableDeclarator"
        @processASTNode(node.id, d+1)
        @processASTNode(node.init, d+1)
      when "Identifier"
        # TODO: normalize variable names somehow?
        # console.log "IDENTIFIER", node.name
        null
      when "StaticMemberExpression", "MemberExpression"
        @processASTNode(node.object, d+1)
        @processASTNode(node.property, d+1)
      else
        null
        # console.log "**END node", d
        # console.log node
    node


  sha1: (message) ->
    notString = typeof message != 'string'
    if notString and message.constructor == ArrayBuffer
      message = new Uint8Array(message)
    h0 = undefined
    h1 = undefined
    h2 = undefined
    h3 = undefined
    h4 = undefined
    block = 0
    code = undefined
    end = false
    t = undefined
    f = undefined
    i = undefined
    j = undefined
    index = 0
    start = 0
    bytes = 0
    length = message.length
    h0 = 0x67452301
    h1 = 0xEFCDAB89
    h2 = 0x98BADCFE
    h3 = 0x10325476
    h4 = 0xC3D2E1F0
    loop
      blocks[0] = block
      blocks[16] = blocks[1] = blocks[2] = blocks[3] = blocks[4] = blocks[5] = blocks[6] = blocks[7] = blocks[8] = blocks[9] = blocks[10] = blocks[11] = blocks[12] = blocks[13] = blocks[14] = blocks[15] = 0
      if notString
        i = start
        while index < length and i < 64
          blocks[i >> 2] |= message[index] << SHIFT[i++ & 3]
          ++index
      else
        i = start
        while index < length and i < 64
          code = message.charCodeAt(index)
          if code < 0x80
            blocks[i >> 2] |= code << SHIFT[i++ & 3]
          else if code < 0x800
            blocks[i >> 2] |= (0xc0 | code >> 6) << SHIFT[i++ & 3]
            blocks[i >> 2] |= (0x80 | code & 0x3f) << SHIFT[i++ & 3]
          else if code < 0xd800 or code >= 0xe000
            blocks[i >> 2] |= (0xe0 | code >> 12) << SHIFT[i++ & 3]
            blocks[i >> 2] |= (0x80 | code >> 6 & 0x3f) << SHIFT[i++ & 3]
            blocks[i >> 2] |= (0x80 | code & 0x3f) << SHIFT[i++ & 3]
          else
            code = 0x10000 + ((code & 0x3ff) << 10 | message.charCodeAt(++index) & 0x3ff)
            blocks[i >> 2] |= (0xf0 | code >> 18) << SHIFT[i++ & 3]
            blocks[i >> 2] |= (0x80 | code >> 12 & 0x3f) << SHIFT[i++ & 3]
            blocks[i >> 2] |= (0x80 | code >> 6 & 0x3f) << SHIFT[i++ & 3]
            blocks[i >> 2] |= (0x80 | code & 0x3f) << SHIFT[i++ & 3]
          ++index
      bytes += i - start
      start = i - 64
      if index == length
        blocks[i >> 2] |= EXTRA[i & 3]
        ++index
      block = blocks[16]
      if index > length and i < 56
        blocks[15] = bytes << 3
        end = true
      j = 16
      while j < 80
        t = blocks[j - 3] ^ blocks[j - 8] ^ blocks[j - 14] ^ blocks[j - 16]
        blocks[j] = t << 1 | t >>> 31
        ++j
      a = h0
      b = h1
      c = h2
      d = h3
      e = h4
      j = 0
      while j < 20
        f = b & c | ~b & d
        t = a << 5 | a >>> 27
        e = t + f + e + 1518500249 + blocks[j] << 0
        b = b << 30 | b >>> 2
        f = a & b | ~a & c
        t = e << 5 | e >>> 27
        d = t + f + d + 1518500249 + blocks[j + 1] << 0
        a = a << 30 | a >>> 2
        f = e & a | ~e & b
        t = d << 5 | d >>> 27
        c = t + f + c + 1518500249 + blocks[j + 2] << 0
        e = e << 30 | e >>> 2
        f = d & e | ~d & a
        t = c << 5 | c >>> 27
        b = t + f + b + 1518500249 + blocks[j + 3] << 0
        d = d << 30 | d >>> 2
        f = c & d | ~c & e
        t = b << 5 | b >>> 27
        a = t + f + a + 1518500249 + blocks[j + 4] << 0
        c = c << 30 | c >>> 2
        j += 5
      while j < 40
        f = b ^ c ^ d
        t = a << 5 | a >>> 27
        e = t + f + e + 1859775393 + blocks[j] << 0
        b = b << 30 | b >>> 2
        f = a ^ b ^ c
        t = e << 5 | e >>> 27
        d = t + f + d + 1859775393 + blocks[j + 1] << 0
        a = a << 30 | a >>> 2
        f = e ^ a ^ b
        t = d << 5 | d >>> 27
        c = t + f + c + 1859775393 + blocks[j + 2] << 0
        e = e << 30 | e >>> 2
        f = d ^ e ^ a
        t = c << 5 | c >>> 27
        b = t + f + b + 1859775393 + blocks[j + 3] << 0
        d = d << 30 | d >>> 2
        f = c ^ d ^ e
        t = b << 5 | b >>> 27
        a = t + f + a + 1859775393 + blocks[j + 4] << 0
        c = c << 30 | c >>> 2
        j += 5
      while j < 60
        f = b & c | b & d | c & d
        t = a << 5 | a >>> 27
        e = t + f + e - 1894007588 + blocks[j] << 0
        b = b << 30 | b >>> 2
        f = a & b | a & c | b & c
        t = e << 5 | e >>> 27
        d = t + f + d - 1894007588 + blocks[j + 1] << 0
        a = a << 30 | a >>> 2
        f = e & a | e & b | a & b
        t = d << 5 | d >>> 27
        c = t + f + c - 1894007588 + blocks[j + 2] << 0
        e = e << 30 | e >>> 2
        f = d & e | d & a | e & a
        t = c << 5 | c >>> 27
        b = t + f + b - 1894007588 + blocks[j + 3] << 0
        d = d << 30 | d >>> 2
        f = c & d | c & e | d & e
        t = b << 5 | b >>> 27
        a = t + f + a - 1894007588 + blocks[j + 4] << 0
        c = c << 30 | c >>> 2
        j += 5
      while j < 80
        f = b ^ c ^ d
        t = a << 5 | a >>> 27
        e = t + f + e - 899497514 + blocks[j] << 0
        b = b << 30 | b >>> 2
        f = a ^ b ^ c
        t = e << 5 | e >>> 27
        d = t + f + d - 899497514 + blocks[j + 1] << 0
        a = a << 30 | a >>> 2
        f = e ^ a ^ b
        t = d << 5 | d >>> 27
        c = t + f + c - 899497514 + blocks[j + 2] << 0
        e = e << 30 | e >>> 2
        f = d ^ e ^ a
        t = c << 5 | c >>> 27
        b = t + f + b - 899497514 + blocks[j + 3] << 0
        d = d << 30 | d >>> 2
        f = c ^ d ^ e
        t = b << 5 | b >>> 27
        a = t + f + a - 899497514 + blocks[j + 4] << 0
        c = c << 30 | c >>> 2
        j += 5
      h0 = h0 + a << 0
      h1 = h1 + b << 0
      h2 = h2 + c << 0
      h3 = h3 + d << 0
      h4 = h4 + e << 0
      unless !end
        break
    HEX_CHARS[h0 >> 28 & 0x0F] + HEX_CHARS[h0 >> 24 & 0x0F] + HEX_CHARS[h0 >> 20 & 0x0F] + HEX_CHARS[h0 >> 16 & 0x0F] + HEX_CHARS[h0 >> 12 & 0x0F] + HEX_CHARS[h0 >> 8 & 0x0F] + HEX_CHARS[h0 >> 4 & 0x0F] + HEX_CHARS[h0 & 0x0F] + HEX_CHARS[h1 >> 28 & 0x0F] + HEX_CHARS[h1 >> 24 & 0x0F] + HEX_CHARS[h1 >> 20 & 0x0F] + HEX_CHARS[h1 >> 16 & 0x0F] + HEX_CHARS[h1 >> 12 & 0x0F] + HEX_CHARS[h1 >> 8 & 0x0F] + HEX_CHARS[h1 >> 4 & 0x0F] + HEX_CHARS[h1 & 0x0F] + HEX_CHARS[h2 >> 28 & 0x0F] + HEX_CHARS[h2 >> 24 & 0x0F] + HEX_CHARS[h2 >> 20 & 0x0F] + HEX_CHARS[h2 >> 16 & 0x0F] + HEX_CHARS[h2 >> 12 & 0x0F] + HEX_CHARS[h2 >> 8 & 0x0F] + HEX_CHARS[h2 >> 4 & 0x0F] + HEX_CHARS[h2 & 0x0F] + HEX_CHARS[h3 >> 28 & 0x0F] + HEX_CHARS[h3 >> 24 & 0x0F] + HEX_CHARS[h3 >> 20 & 0x0F] + HEX_CHARS[h3 >> 16 & 0x0F] + HEX_CHARS[h3 >> 12 & 0x0F] + HEX_CHARS[h3 >> 8 & 0x0F] + HEX_CHARS[h3 >> 4 & 0x0F] + HEX_CHARS[h3 & 0x0F] + HEX_CHARS[h4 >> 28 & 0x0F] + HEX_CHARS[h4 >> 24 & 0x0F] + HEX_CHARS[h4 >> 20 & 0x0F] + HEX_CHARS[h4 >> 16 & 0x0F] + HEX_CHARS[h4 >> 12 & 0x0F] + HEX_CHARS[h4 >> 8 & 0x0F] + HEX_CHARS[h4 >> 4 & 0x0F] + HEX_CHARS[h4 & 0x0F]

