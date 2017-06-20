require 'u3d/iniparser'
require 'u3d_core/helper'
require 'net/http'

module U3d
  # Takes care of fectching versions and version list
  module UnityVersions
    #####################################################
    # @!group URLS: Locations to fetch information from
    #####################################################
    #URL for the forum thread listing all the Linux releases
    UNITY_LINUX_DOWNLOADS = 'https://forum.unity3d.com/threads/unity-on-linux-release-notes-and-known-issues.350256/'.freeze
    # URL for the main releases for Windows and Macintosh
    UNITY_DOWNLOADS = 'https://unity3d.com/get-unity/download/archive'.freeze
    # URL for the patch releases for Windows and Macintosh
    UNITY_PATCHES = 'https://unity3d.com/unity/qa/patch-releases'.freeze
    # URL for the beta releases list, they need to be accessed after
    UNITY_BETAS = 'https://unity3d.com/unity/beta/archive'.freeze
    # URL for a specific beta, takes into parameter a version string (%s)
    UNITY_BETA_URL = 'https://unity3d.com/unity/beta/unity%s'.freeze

    #####################################################
    # @!group REGEX: expressions to interpret data
    #####################################################
    # Captures a version and its base url
    MAC_DOWNLOAD = %r{"(https?://[\w/\.-]+/[0-9a-f]{12}/)MacEditorInstaller/[a-zA-Z0-9/\.]+-(\d+\.\d+\.\d+\w\d+)\.?\w+"}
    WIN_DOWNLOAD = %r{"(https?://[\w/\.-]+/[0-9a-f]{12}/)Windows..EditorInstaller/[a-zA-Z0-9/\.]+-(\d+\.\d+\.\d+\w\d+)\.?\w+"}
    LINUX_DOWNLOAD = %r{"(https?://[\w/\._-]+/unity\-editor\-installer\-(\d+\.\d+\.\d+\w\d+).*\.sh)"}
    # Captures a beta version in html page
    UNITY_BETAVERSION_REGEX = %r{\/unity\/beta\/unity(\d+\.\d+\.\d+\w\d+)"}
    UNITY_EXTRA_DOWNLOAD_REGEX = %r{"(https?:\/\/[\w\/.-]+\.unity3d\.com\/(\w+))\/[a-zA-Z\/.-]+\/download.html"}

    class << self
      def list_available(os: nil)
        os ||= U3dCore::Helper.operating_system

        case os
        when :linux
          return U3d::UnityVersions::LinuxVersions.list_available
        when :mac
          return U3d::UnityVersions::MacVersions.list_available
        when :win
          return U3d::UnityVersions::WindowsVersions.list_available
        else
          raise ArgumentError, "Operating system #{os} not supported"
        end
      end

      def fetch_version(url, pattern)
        hash = {}
        data = Utils.get_ssl(url)
        results = data.scan(pattern)
        results.each { |capt| hash[capt[1]] = capt[0] }
        return hash
      end

      def fetch_betas(url, pattern)
        hash = {}
        data = Utils.get_ssl(url)
        results = data.scan(UNITY_BETAVERSION_REGEX).uniq
        results.each { |beta| hash.merge!(fetch_version(UNITY_BETA_URL % beta[0], pattern)) }
        hash
      end
    end

    class LinuxVersions
      class << self
        def list_available
          UI.message 'Loading Unity releases'
          request = nil
          response = nil
          data = ''
          uri = URI(UNITY_LINUX_DOWNLOADS)
          Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
            request = Net::HTTP::Get.new uri
            request['Connection'] = 'keep-alive'
            response = http.request request

            case response
            when Net::HTTPSuccess then
              # Successfully retrieved forum content
              data = response.body
            when Net::HTTPRedirection then
              # A session must be opened with the server before accessing forum
              res = nil
              cookie_str = ''
              # Store the name and value of the cookies returned by the server
              response['set-cookie'].gsub(/\s+/, '').split(',').each do |c|
                cookie_str << c.split(';', 2)[0] + '; '
              end
              cookie_str.chomp!('; ')

              # It should be the Unity register API
              uri = URI(response['location'])
              Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http_api|
                request = Net::HTTP::Get.new uri
                request['Connection'] = 'keep-alive'
                res = http_api.request request
              end

              raise 'Unexpected result' unless res.is_a? Net::HTTPRedirection
              # It should be a redirection to the forum to perform authentication
              uri = URI(res['location'])

              request = Net::HTTP::Get.new uri
              request['Connection'] = 'keep-alive'
              request['Cookie'] = cookie_str

              res = http.request request

              raise 'Unable to establish a session with Unity forum' unless res.is_a? Net::HTTPRedirection

              cookie_str << '; ' + res['set-cookie'].gsub(/\s+/, '').split(';', 2)[0]

              uri = URI(res['location'])

              request = Net::HTTP::Get.new uri
              request['Connection'] = 'keep-alive'
              request['Cookie'] = cookie_str

              res = http.request request

              data = res.body if res.is_a? Net::HTTPSuccess
            else raise "Request failed with status #{response.code}"
            end
          end
          data.gsub(/[ \t]+/, '').each_line { |l| puts l if /<a href=/ =~ l }
          versions = {}
          results = data.scan(LINUX_DOWNLOAD)
          results.each do |capt|
            versions[capt[1]] = capt[0]
          end
          if versions.count.zero?
            UI.important 'Found no releases'
          else
            UI.success "Found #{versions.count} releases."
          end
          versions
        end
      end
    end

    class MacVersions
      class << self
        def list_available
          versions = {}
          UI.message 'Loading Unity releases'
          current = UnityVersions.fetch_version(UNITY_DOWNLOADS, MAC_DOWNLOAD)
          UI.success "Found #{current.count} releases." if current.count.nonzero?
          versions = versions.merge(current)
          UI.message 'Loading Unity patch releases'
          current = UnityVersions.fetch_version(UNITY_PATCHES, MAC_DOWNLOAD)
          UI.success "Found #{current.count} patch releases." if current.count.nonzero?
          versions = versions.merge(current)
          UI.message 'Loading Unity beta releases'
          current = UnityVersions.fetch_betas(UNITY_BETAS, MAC_DOWNLOAD)
          UI.success "Found #{current.count} beta releases." if current.count.nonzero?
          versions = versions.merge(current)
          versions
        end
      end
    end

    class WindowsVersions
      class << self
        def list_available
          versions = {}
          UI.message 'Loading Unity releases'
          current = UnityVersions.fetch_version(UNITY_DOWNLOADS, WIN_DOWNLOAD)
          UI.success "Found #{current.count} releases." if current.count.nonzero?
          versions = versions.merge(current)
          UI.message 'Loading Unity patch releases'
          current = UnityVersions.fetch_version(UNITY_PATCHES, WIN_DOWNLOAD)
          UI.success "Found #{current.count} patch releases." if current.count.nonzero?
          versions = versions.merge(current)
          UI.message 'Loading Unity beta releases'
          current = UnityVersions.fetch_betas(UNITY_BETAS, WIN_DOWNLOAD)
          UI.success "Found #{current.count} beta releases." if current.count.nonzero?
          versions = versions.merge(current)
          versions
        end
      end
    end
  end
end
