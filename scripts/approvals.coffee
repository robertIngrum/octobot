# Description:
#   Show pull requests that need approval
# Commands:
#   hubot thumbs -- Shows all pull requests awaiting approval for Recognize
#   hubot ears   -- Shows all pull requests awaiting approval for Listen
#   hubot prs    -- Shows all pull requests awaiting approval for both products

_  = require("underscore")
ta = require("time-ago")()

CMDS = {
    thumbs: { project: "recognize", env: "HUBOT_GITHUB_REPO" },
    ears: { project: "signals", env: "HUBOT_LISTEN_REPO" },
    dashboards: { project: "digital signage", env: "HUBOT_DASHBOARD_REPO" },
    users: { project: "user sauce", env: "HUBOT_USERS_REPO" },
   }

ASK_REGEX = /thumbs*|ears*|prs*|dashboards*/i

module.exports = (robot) ->
  github = require("githubot")(robot)
  query_params = state: "open", sort: "created"
  query_params.per_page=100
  base_url = process.env.HUBOT_GITHUB_API

  getPulls = (cmd, msg) ->
    repo = process.env[cmd.env]
    github.get "#{base_url}/repos/#{repo}/pulls", query_params, (pulls) ->
      if pulls.length
        notReadyCount = 0
        approvedCount = 0
        _.each(pulls, (pull) ->
          github.get "#{pull.issue_url}", (issue) ->
            notReadyForReview = _.any(issue.labels, (label) ->
              label.name.includes('not-ready-for-review') || label.name.includes('example'))

            notReadyCount += 1 if notReadyForReview

            unless notReadyForReview
              github.get "#{pull.url}/reviews", (reviews) ->
                approvalCount = _.filter(reviews, (review) ->
                                  review.state == 'APPROVED').length
                approvalsNeeded = Math.max((2 - approvalCount), 0)

                github.get "#{pull.url}", (pull) ->
                  size = pull.additions
                  printSize = if size > 10000 then '╭∩╮(-_-)╭∩╮' else if size > 2000 then "#{size} (╯°□°)╯︵ ┻━┻" else if size > 500 then "#{size} ಠ_ಠ" else size

                  if approvalsNeeded
                    requestedReviewers = _.map(pull.requested_reviewers, (reviewer) ->
                      reviewer.login).join(', ')
                    baseMessage = """
                      *<#{pull.html_url}|#{pull.title}> Project: _#{cmd.project}_ Size: #{printSize}*
                      \nSubmitted by #{pull.user.login} _#{ta.ago(pull.created_at)}_
                      \nNeeds #{approvalsNeeded} more
                    """
                    requestMessage = "\nReview requested from #{requestedReviewers}"
                    message = if requestedReviewers then baseMessage.concat(requestMessage) else baseMessage
                    msg.send message
                  else
                    approvedCount += 1
          msg.send "No pull requests for *#{cmd.project}* need review! :tada:" if (notReadyCount + approvedCount) == pulls.length
      )
      else
        msg.send "no pull requests open for *#{cmd.project}*! :tada:"

  robot.respond ASK_REGEX, (msg) ->
   if msg.message.text.match(/prs*/)
      _.each(_.values(CMDS), (cmd) =>
        getPulls(cmd, msg))
    else if msg.message.text.match(/thumbs*/)
      getPulls(CMDS.thumbs, msg)
    else if msg.message.text.match(/dashboards*/)
      getPulls(CMDS.dashboards, msg)
    else if msg.message.text.match(/users*/)
      getPulls(CMDS.users, msg)
    else
      getPulls(CMDS.ears, msg)
