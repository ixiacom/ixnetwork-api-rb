#!/usr/bin/env ruby

# IxNetwork API Bindings
#
# Copyright © 1997 - 2017 by IXIA
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"),
# to deal in the Software without restriction, including without limitation
# the rights to use, copy, modify, merge, publish, distribute, sublicense,
# and/or sell copies of the Software, and to permit persons to whom the
# Software is furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

require 'socket'
require 'etc'
require 'pathname'

class IxNetError < StandardError
    #"""Default IxNet error"""
end

class IxNetwork
    def initialize()
        @_root = '::ixNet::OBJ-/'
        @_null = '::ixNet::OBJ-null'
        @_socket = nil
        @_proxySocket = nil
        @_connectTokens = ''
        @_evalError = '1'
        @_evalSuccess = '0'
        @_evalResult = '0'
        @_addContentSeparator = 0
        @_firstItem = true
        @_sendContent = Array.new
        @_buffer = false
        @_sendBuffer = Array.new
        @_decoratedResult = Array.new
        @_filename = nil
        @_debug = false
        @_async = false
        @_timeout = nil
        @_OK = '::ixNet::OK'
        @_version = '8.40.1124.8'
    end

    def setDebug(debug)
        @_debug = debug
        return self
    end

    def getRoot()
        return @_root
    end

    def getNull()
        return @_null
    end

    def setAsync()
        @_async = true;
        return self
    end

    def setTimeout(timeout)
        @_timeout = timeout
        return self
    end

    def __initialConnect(address, port, options)
        # make an initial socket connection
        # this will keep trying as it could be connecting to the proxy
        # which may not have an available application instance at that time
        attempts = 0
        while true
            begin
				sd = Socket.getaddrinfo(address,Socket::SOCK_STREAM,Socket::AF_INET)
                @_socket = Socket.new(Socket::AF_INET, Socket::SOCK_STREAM, 0)
                @_socket.connect(Socket.pack_sockaddr_in(port, sd[0][2]))
                break
            rescue SocketError => e
                if @_proxySocket != nil and attempts < 120 then
                    time.sleep(2)
                    attempts += 1
                else
                    self.__Close()
                    raise IxNetError,e.to_s + e.backtrace.to_s
                end
            end
        end

        # a socket connection has been made now read the type of connection
        # setup to timeout if the remote endpoint is not valid
        optval = [30, 0].pack("l_2")
        @_socket.setsockopt Socket::SOL_SOCKET, Socket::SO_RCVTIMEO, optval
        read, write, error = select([@_socket], [], [], 30)
        if read.length == 0 and write.length == 0 and error.length == 0 then
            self.__Close()
            raise IxNetError,'Connection handshake timed out after 30 seconds'
        end
        optval = [0, 0].pack("l_2")
        @_socket.setsockopt Socket::SOL_SOCKET, Socket::SO_RCVTIMEO, optval

        # process the results from the endpoint
        connectString = self.__Recv()
        if connectString == 'proxy' then
            @_socket.send(options,0)
            @_connectTokens = self.__Recv().to_s
            connectTokensArray = @_connectTokens.split()
            connectTokens = Hash[connectTokensArray.values_at(* connectTokensArray.each_index.select {|i| i.even?}).zip \
            connectTokensArray.values_at(* connectTokensArray.each_index.select {|i| i.odd?})]
            @_proxySocket = @_socket
            @_socket = nil
            self.__initialConnect(address, connectTokens['-port'], '')
        end
    end

    def connect(address, *args)
        begin
            if @_socket != nil then
                self.__SendRecv('ixNet', 'help')
            end
        rescue
            self.__Close()
        end

        begin
            nameValuePairs = {}
            name = nil
            for arg in args
                if arg.to_s.start_with?('-') then
                    if name.nil? then
                        name = arg.to_s
                    else
                        nameValuePairs[name] = ''
                    end
                elsif !name.nil?
                    nameValuePairs[name] = arg.to_s
                    name = nil
                end
            end
            if  not nameValuePairs.include?('-port') then
                nameValuePairs['-port'] = 8009
            end

            options = '-clientusername ' + Etc.getlogin
            if  nameValuePairs.include?('-serverusername') then
                options += ' -serverusername ' + nameValuePairs['-serverusername']
            end
            if  nameValuePairs.include?('-connectTimeout') then
                options += ' -connectTimeout ' + nameValuePairs['-connectTimeout']
            end
            if  nameValuePairs.include?('-closeServerOnDisconnect') then
                options += ' -closeServerOnDisconnect ' + nameValuePairs[-closeServerOnDisconnect]
            else
                options += ' -closeServerOnDisconnect true'
            end

            if @_socket.nil? then
                self.__initialConnect(address, nameValuePairs['-port'].to_i, options)
                conRes = self.__SendRecv('ixNet', 'connect', address,'-clientType', 'ruby', *args)
                self._CheckClientVersion()
                return conRes
            else
                sockInfo = @_socket.getpeername()
                return "Cannot connect to #{address}:#{nameValuePairs['-port']} as a connection is already established to #{sockInfo[0]}:#{sockInfo[1]}. Please execute disconnect before trying this command again."
            end
        rescue SocketError => e
            self.__Close()
            raise IxNetError,"Unable to connect to host:"+address.to_s+" port:"+nameValuePairs['-port'].to_s+". Error:"+e.to_s
        end
    end

    def disconnect()
        response = self.__SendRecv('ixNet', 'disconnect')
        self.__Close()
        return response
    end

    def help(*args)
        return self.__SendRecv('ixNet', 'help', *args)
    end

    def setSessionParameter(*args)
        if args.length % 2 == 0 then
            return self.__SendRecv('ixNet', 'setSessionParameter', *args)
        else
            raise IxNetError,"setSessionParameter requires an even number of name/value pairs"
        end
    end

    def getVersion()
        if @_socket.nil? then
            return @_version
        else
            return self.__SendRecv('ixNet', 'getVersion')
        end
    end

    def getParent(objRef)
        return self.__SendRecv('ixNet', 'getParent', objRef)
    end

    def exists(objRef)
        return self.__SendRecv('ixNet', 'exists', self.__CheckObjRef(objRef))
    end

    def commit()
        return self.__SendRecv('ixNet', 'commit')
    end

    def rollback()
        return self.__SendRecv('ixNet', 'rollback')
    end

    def execute(*args)
        return self.__SendRecv('ixNet', 'exec', *args)
    end

    def add(objRef, child, *args)
        return self.__SendRecv('ixNet', 'add', self.__CheckObjRef(objRef), child, *args)
    end

    def remove(objRef)
        return self.__SendRecv('ixNet', 'remove', objRef)
    end

    def setAttribute(objRef, name, value)
        @_buffer = true
        return self.__SendRecv('ixNet', 'setAttribute', self.__CheckObjRef(objRef), name, value)
    end

    def setMultiAttribute(objRef, *args)
        @_buffer = true
        return self.__SendRecv('ixNet', 'setMultiAttribute', self.__CheckObjRef(objRef), *args)
    end

    def getAttribute(objRef, name)
        return self.__SendRecv('ixNet', 'getAttribute', self.__CheckObjRef(objRef), name)
    end

    def getList(objRef, child)
        return self.__SendRecv('ixNet', 'getList', self.__CheckObjRef(objRef), child)
    end

    def getFilteredList(objRef, child, name, value)
        return self.__SendRecv('ixNet', 'getFilteredList', self.__CheckObjRef(objRef), child, name, value)
    end

    def adjustIndexes(objRef, object)
        return self.__SendRecv('ixNet', 'adjustIndexes', self.__CheckObjRef(objRef), object)
    end

    def remapIds(localIdList)
        #if type(localIdList) is tuple then
        #  localIdList = list(localIdList)
        #end
        return self.__SendRecv('ixNet', 'remapIds', localIdList)
    end

    def getResult(resultId)
        return self.__SendRecv('ixNet', 'getResult', resultId)
    end

    def wait(resultId)
        return self.__SendRecv('ixNet', 'wait', resultId)
    end

    def isDone(resultId)
        return self.__SendRecv('ixNet', 'isDone', resultId)
    end

    def isSuccess(resultId)
        return self.__SendRecv('ixNet', 'isSuccess', resultId)
    end

    def writeTo(filename, *args)
        if args.any? { |word| '-ixNetRelative'.include?(word)} then
            return self.__SendRecv('ixNet', 'writeTo', filename,args.join("\02"))
        else
            return self.__CreateFileOnServer(filename)
        end
    end

    def readFrom(filename, *args)
        if args.any? { |word| '-ixNetRelative'.include?(word)} then
            return self.__SendRecv('ixNet', 'readFrom', filename,args.join("\02"))
        else
            return self.__PutFileOnServer(filename)
        end
    end

    def __CheckObjRef(objRef)
        if (objRef.is_a? String) == false then
            raise IxNetError,'The objRef parameter must be String instead of ' + objRef.class.to_s
        else
            return objRef
        end
    end

    def __PutFileOnServer(filename)
        truncatedFilename = Pathname.new(filename).basename
        fid = File.open(filename, 'rb')
        self.__Send("<001><005><007%s>%s<009%s>" % [filename.length, filename,File.size(filename)])
        self.__SendBinary(fid.read())
        fid.close()
        remoteFilename = self.__Recv()

        return self.__SendRecv('ixNet', 'readFrom', remoteFilename,'-ixNetRelative')
    end

    def __CreateFileOnServer(filename)
        self.__Send("<001><006><007%s>%s<009>" % [filename.length, filename])
        remoteFilename = self.__Recv()
        return self.__SendRecv('ixNet', 'writeTo', remoteFilename,'-ixNetRelative', '-overwrite')
    end

    def __Close()
        begin
            if @_socket then
                @_socket.close()
            end
        rescue
            # clear exceptions
        end
        begin
            if @_proxySocket then
                @_proxySocket.close()
            end
        rescue
            # clear exceptions
        end
        @_socket = nil
        @_proxySocket = nil
    end

    def __Join(*args)
        for arg in args
            if arg.class == Array then
                if @_addContentSeparator == 0 then
                    @_sendContent.push("\02")
                end
                if @_addContentSeparator > 0 then
                    @_sendContent.push('{')
                end
                @_addContentSeparator += 1
                @_firstItem = true
                if arg.length == 0 then
                    @_sendContent.push('{}')
                else
                    for item in arg
                        self.__Join(item)
                    end
                end
                if @_addContentSeparator > 1 then
                    @_sendContent.push('}')
                end
                @_addContentSeparator -= 1
            else
                if @_addContentSeparator == 0 and @_sendContent.length > 0 then
                    @_sendContent.push("\02")
                elsif @_addContentSeparator > 0
                    if @_firstItem == false then
                        @_sendContent.push(' ')
                    else
                        @_firstItem = false
                    end
                end
                if arg.nil? then
                    arg = ''
                elsif !(arg.is_a? String)
                    arg = arg.to_s
                end
                if arg.length == 0 and @_sendContent.length > 0 then
                    @_sendContent.push('{}')
                elsif arg.include?(' ') and @_addContentSeparator > 0
                    @_sendContent.push('{'+arg+'}')
                else
                    @_sendContent.push(arg)
                end
            end
        end
        return
    end

    def __SendRecv(*args)
        if @_socket.nil? then
            raise IxNetError,'not connected'
        end

        @_addContentSeparator = 0
        @_firstItem = true

        argList = args

        if @_async then
            argList.insert(1, '-async')
        end

        if !@_timeout.nil? then
            argList.insert(1, '-timeout')
            argList.insert(2, @_timeout)
        end

        for item in argList
            self.__Join(item)
        end

        @_sendContent.push("\03")
        @_sendBuffer.push(@_sendContent.join(''));
        if @_buffer == false then
            buffer = @_sendBuffer.join('')
            if @_debug then
                puts "Sending: " + buffer
            end
            self.__Send("<001><002><009%s>%s" % [buffer.length,buffer])
            @_sendBuffer = Array.new
        end

        @_async = false
        @_timeout = nil
        @_buffer = false
        @_sendContent = Array.new

        if @_sendBuffer.length > 0 then
            return @_OK
        else
            return self.__Recv()
        end
    end

    def __Send(content)
        if @_socket.nil? then
            raise IxNetError,'not connected'
        else
            begin
                if content.is_a? String then
                    content = content
                end
                @_socket.send(content,0)
            rescue SocketError => e
                self.__Close()
                raise IxNetError,"Error:"+e
            end
        end
    end

    def __SendBinary(content)
        if @_socket.nil? then
            raise IxNetError,"not connected"
        else
            begin
                @_socket.send(content,0)
            rescue SocketError => e
                self.__Close()
                raise IxNetError,"Error:"+e
            end
        end
    end

    def __Recv()
        @_decoratedResult = Array.new
        responseBuffer = ''
        begin
            while true
                responseBuffer = ''
                commandId = nil
                contentLength = 0

                while true
                    responseBuffer += @_socket.recv(1)
                    startIndex = responseBuffer.index('<')
                    stopIndex = responseBuffer.index('>')
                    if !startIndex.nil? and !stopIndex.nil? then
                        @si = startIndex + 1
                        @ei = startIndex + 3
                        commandId = responseBuffer[@si..@ei].to_i
                        if (startIndex + 4) < stopIndex then
                            @si = startIndex + 4
                            @ei = stopIndex
                            contentLength = responseBuffer[@si..@ei].to_i
                        end
                        break
                    end
                end
                if commandId == 1 then
                    @_evalResult = @_evalError
                    @_socket.recv(contentLength)
                elsif commandId == 3
                    @_socket.recv(contentLength)
                elsif commandId == 4
                    @_evalResult = @_socket.recv(contentLength)
                elsif commandId == 7
                    @_filename = @_socket.recv(contentLength)
                elsif commandId == 8
                    binaryFile = open(@_filename, 'w+b')
                    chunk = ''
                    bytesToRead = 32767
                    while contentLength > 0
                        if contentLength < bytesToRead then
                            bytesToRead = contentLength
                        end
                        chunk = @_socket.recv(bytesToRead)
                        binaryFile.write(chunk)
                        contentLength -= chunk.length
                    end
                    binaryFile.close()
                elsif commandId == 9
                    @_decoratedResult = Array.new
                    chunk = ''
                    bytesToRead = 32767
                    while contentLength > 0
                        if contentLength < bytesToRead then
                            bytesToRead = contentLength
                        end
                        chunk = @_socket.recv(bytesToRead)
                        @_decoratedResult.push(chunk)
                        contentLength -= chunk.length
                    end
                    break
                end
            end

        rescue SocketError => e
            self.__Close()
            raise IxNetError,"Recv failed. Error:"+e.to_s
        end

        if @_debug then
            puts "Received: " + @_decoratedResult.join('')
        end

        if @_evalResult == @_evalError then
            raise IxNetError,@_decoratedResult.join('')
        end

        if @_decoratedResult.length > 0 and @_decoratedResult[0].start_with?("\01") then
            @_decoratedResult[0] = @_decoratedResult[0].sub("\01", '')
            return eval(@_decoratedResult.join(""))
        else
            return @_decoratedResult.join("")
        end
    end

    def _CheckClientVersion ()
        if @_version != self.getVersion() then
            puts "WARNING: IxNetwork Ruby library version " + @_version + " is not matching the IxNetwork client version " + self.getVersion()
        end
    end

end
