#lang concourse/docs

@title[#:style '(quiet unnumbered)]{v0.51.0}

This release contains @emph{backwards-incompatible} changes that clean up the
semantics of @secref{put-step} and @secref{get-step} within build plans.

@itemlist[
  @item{
    In a given build plan, @emph{all} @secref{get-step} steps are considered
    inputs to the plan's outer job, and have their version determined before
    the build starts running. Previously only the "firstmost" @code{get}s (or
    ones with @code{passed} constraints) were considered inputs, which was
    pretty confusing.

    As part of this, @code{trigger} now defaults to @code{false}, rather than
    @code{true}.

    To auto-trigger based on a @secref{get-step} step in your plan, you must
    now explicitly say @code{trigger: true}.

    So, a build plan that looks like...:

    @codeblock["yaml"]{
    - aggregate:
      - get: a
      - get: b
        trigger: false
    - get: c
    }

    ...would be changed to...:

    @codeblock["yaml"]{
    - aggregate:
      - get: a
        trigger: true
      - get: b
    - get: c
    }

    ...with one subtle change: the version of @code{c} is determined before
    the build starts, rather than fetched arbitrarily in the middle.
  }

  @item{
    All @secref{put-step} steps now imply a @secref{get-step} of the created
    resource version. This allows build plans to produce an artifact and use
    the artifact in later steps.

    These implicit @secref{get-step} steps are displayed differently in the UI
    so as to not be confused with explicit @secref{get-step} steps.

    So, a build plan that looks like...:

    @codeblock["yaml"]{
    - get: a
    - put: b
    - get: b
    - put: c
      params: {b/something}
    }

    ...would be changed to...:

    @codeblock["yaml"]{
    - get: a
    - put: b
    - put: c
      params: {b/something}
    }

    The main difference being that this now @emph{guarantees} that the version
    of @code{b} that @code{c} uses is the same version that was created.

    Note that, given the first change, this is the only way for new versions
    to appear in the middle of a build plan.
  }
]
