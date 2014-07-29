#
# Cookbook Name:: twc
# Libary:: Chef::Deployer
#
# Copyright 2013, The Weather Company, Inc.
#
# All rights reserved - Do Not Redistribute
#

=begin
def s3_file_local_md5(path,criteria={
																	:s3_multipart_threshold     => 16 * 1024 * 1024,
																	:s3_multipart_min_part_size => 5 * 1024 * 1024,
																	:s3_multipart_max_parts     => 10000
																})
if File.size(path) > criteria[:s3_multipart_threshold]
length = criteria[:s3_multipart_min_part_size]
offset = 0
md5str = ''
begin
	chunk = File.read(path,length,offset, { :mode => 'rb' })
	#noinspection RubyArgCount
	md5 = Digest::MD5.digest(chunk)
	#Chef::Log.debug(md5)
	#noinspection RubyArgCount
	md5str << md5
	offset += length
end while chunk.length == length
#noinspection RubyArgCount
Digest::MD5.hexdigest(md5str)
else
Digest::MD5.file(path).hexdigest
end
# Oh no one of the new ETags for multipart uploads
# See: http://permalink.gmane.org/gmane.comp.file-systems.s3.s3tools/583
# And: https://forums.aws.amazon.com/thread.jspa?messageID=203510#203510
# and: http://stackoverflow.com/questions/6591047/etag-definition-changed-in-amazon-s3
=begin
[2014-01-10 Christo] Unfortunately this does not provide a way out ... :(
s3 = Aws::S3.new(
		:access_key_id => key,
:secret_access_key => secret)
resp = s3.head_object(
# required
:bucket    => bucket,
:key       => path, #.gsub(%r(^/),''),
)
Chef::Log.info resp.contents.ai
if resp and resp.size > 0
resp[0][:etag]
else
''
end
-end
end
=end


#def deployPackage(*args_p)
#	Deployer.deployPackage(Deployer.deployer_getArgs(args_p))
#end