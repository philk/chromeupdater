# ChromeController.rb
# ChromeUpdater
#
# Created by Phil Kates on 12/15/09.
# Copyright 2009 __MyCompanyName__. All rights reserved.

class ChromeController < NSWindowController
  attr_accessor :progressIndicator, :downloadLabel, :buildLabel, :updateButton, :cancelButton

  def awakeFromNib
#    @progressIndicator.setIndeterminate = false
    @progressIndicator.startAnimation(nil)
    @progressIndicator.setIndeterminate(false)
    @build_delegate = Object.new
    @zip_delegate = Object.new
  end
  
  def quit(sender)
    exit
  end
  
  def update_chrome(sender)
    @updateButton.setEnabled(false)
    get_build
  end
  
  def unzip_chrome
    @downloadLabel.stringValue = "Extracting"
    system("unzip -o /tmp/chrome-mac.zip -d /tmp")
    install_chrome
  end
  def install_chrome
    @downloadLabel.stringValue = "Installing"
    if File.exist?("/Applications/Chromium.app")
	    FileUtils.remove_dir("/Applications/Chromium.app")
    end
	  FileUtils.mv("/tmp/chrome-mac/Chromium.app", "/Applications/")
	  FileUtils.remove_dir("/tmp/chrome-mac")
	  @progressIndicator.stopAnimation(nil)
	  @progressIndicator.setIndeterminate(false)
	  @progressIndicator.setDoubleValue(100.00)
    @downloadLabel.stringValue = "Done"
    @updateButton.setEnabled(true)
  end

  def get_build
    @progressIndicator.setIndeterminate(true)
    @progressIndicator.startAnimation(nil)
    @downloadLabel.stringValue = "Getting build number..."
    chrome_build = ChromeBuild.new
    chrome_build.delegate = lambda do |data|
      result = NSString.alloc.initWithData data, encoding:NSUTF8StringEncoding
      @buildLabel.stringValue = "Build: #{result}"
      get_zip(result)
    end
    chrome_build.buf = NSMutableData.new
    chrome_build.response = nil

    url = NSURL.URLWithString("http://build.chromium.org/buildbot/snapshots/chromium-rel-mac/LATEST")
    req = NSURLRequest.requestWithURL(url)
    chrome_build.conn = NSURLConnection.alloc.initWithRequest(req, delegate:chrome_build)
  end
  def get_zip(build)
    @progressIndicator.setIndeterminate(false)
    zip = ChromeZip.new
    zip.delegate = lambda do |data, error|
      if error
        alert = NSAlert.new
        alert.setMessageText(error)
        alert.runModal()
      else
        data.writeToFile("/tmp/chrome-mac.zip", atomically:true)
        @progressIndicator.setIndeterminate(true)
        unzip_chrome
      end
    end
    zip.progress = lambda do |progress|
      @progressIndicator.setDoubleValue(progress)
      @downloadLabel.stringValue = "Downloading..." + "#{progress.to_i}%"
    end
    zip.buf = NSMutableData.new
    zip.dataSize = 0
    zip.response = nil
    url = NSURL.URLWithString("http://build.chromium.org/buildbot/snapshots/chromium-rel-mac/#{build}/chrome-mac.zip")
    # url = NSURL.URLWithString("http://build.chromium.org/buildbot/snapshots/chromium-rel-mac/LATEST")
    req = NSURLRequest.requestWithURL(url)
    zip.conn = NSURLConnection.alloc.initWithRequest(req, delegate:zip)
    zip.conn.start
  end

end

class ChromeBuild
  attr_accessor :delegate, :buf, :response, :conn, :build
  def cancel
    if @conn
      @conn.cancel
      @conn = nil
    end
  end
  def connectionDidFinishLoading(connection)
    @delegate.call(@buf)
    @build = NSString.alloc.initWithData(@data, encoding:NSUTF8StringEncoding)
  end

  def connection(conn, didReceiveData:receivedData)
    return if @conn != conn
    @buf.appendData(receivedData)
  end
  
  def connection(conn, didReceiveResponse:response)
    return if @conn != conn
    @response = response
  end
  
  def connection(conn, didFailWithError:err)
    if @conn == conn
      @delegate.call(false)
    end
    @conn = nil
  end
  
  def connection(conn, willSendRequest:req, redirectResponse:res)
    return nil if @conn != conn
    if res && res.statusCode == 302
      @delegate.call(req.URL.to_s)
      @conn = nil
      nil
    else
      req
    end
  end
end

class ChromeZip
  attr_accessor :delegate, :buf, :response, :conn, :progress, :dataSize, :totalSize, :started
  def connectionDidFinishLoading(connection)
    @delegate.call(@buf, nil)
  end

  def connection(conn, didReceiveData:recData)
    @buf.appendData(recData)
    @dataSize = @dataSize + recData.length
    @progress.call((@dataSize.to_f / @totalSize.to_f) * 100)
  end
  
  def connection(conn, didReceiveResponse:response)
    @totalSize = response.allHeaderFields["Content-Length"]
  end
  
  def connection(conn, didFailWithError:err)
    if @conn == conn
      @delegate.call(false, err)
    end
    @conn = nil
  end
  
  # def download(conn, willSendRequest:req, redirectResponse:res)
  #   req
  # end
end