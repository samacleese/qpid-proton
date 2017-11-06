#!/usr/bin/enc ruby
#
# Licensed to the Apache Software Foundation (ASF) under one
# or more contributor license agreements.  See the NOTICE file
# distributed with this work for additional information
# regarding copyright ownership.  The ASF licenses this file
# to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance
# with the License.  You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing,
# software distributed under the License is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied.  See the License for the
# specific language governing permissions and limitations
# under the License.
#

require 'minitest/autorun'
require 'qpid_proton'
require 'socket'

class ExampleTest < MiniTest::Test

  def run_script(script, port)
    assert File.exist? script
    cmd = [RbConfig.ruby, script]
    cmd += ["-a", ":#{port}/examples"] if port
    return IO.popen(cmd)
  end


  def assert_output(script, want, port=nil)
    out = run_script(script, port)
    assert_equal want, out.read.strip
  end

  def test_helloworld
    assert_output("helloworld.rb", "Hello world!", $port)
  end

  def test_send_recv
    assert_output("simple_send.rb", "All 100 messages confirmed!", $port)
    want = (0..99).reduce("") { |x,y| x << "Received: sequence #{y}\n" }
    assert_output("simple_recv.rb", want.strip, $port)
  end

  def test_client_server
    want =  <<EOS
-> Twas brillig, and the slithy toves
<- TWAS BRILLIG, AND THE SLITHY TOVES
-> Did gire and gymble in the wabe.
<- DID GIRE AND GYMBLE IN THE WABE.
-> All mimsy were the borogroves,
<- ALL MIMSY WERE THE BOROGROVES,
-> And the mome raths outgrabe.
<- AND THE MOME RATHS OUTGRABE.
EOS
    srv = run_script("server.rb", $port)
    assert_output("client.rb", want.strip, $port)

  ensure
    Process.kill :TERM, srv.pid if srv
  end
end

# Start the broker before all tests.
$port = TCPServer.open(0) do |s| s.addr[1]; end # find an unused port
$broker = spawn("#{RbConfig.ruby} broker.rb -a :#{$port}")

# Wait for the broker to be listening
deadline = Time.now + 5
begin
  TCPSocket.open("", $port).close
rescue Errno::ECONNREFUSED
  retry if Time.now < deadline
  raise
end

# Kill the broker after all tests
MiniTest.after_run do
  Process.kill(:TERM, $broker) if $broker
end
