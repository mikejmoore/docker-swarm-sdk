require 'spec_helper'

SingleCov.not_covered!

describe "Coverage" do
  it "has coverage for all tests" do
    SingleCov.assert_used
  end

  it "has tests for all files" do
    SingleCov.assert_tested untested: %w[
      lib/docker/swarm/node.rb
      lib/docker/swarm/service.rb
      lib/docker/swarm/swarm.rb
    ]
  end
end
