request = require("request")
require('request-debug')(request);

Q = require("q")
qs = require("querystring")

module.exports = (cache) ->
	return {
		make_request : (r, method, url, options) ->
			defer = Q.defer()

			if r.error?
				defer.reject new Error('Not authenticated for provider \'' + r.provider + '\'')
				return defer.promise

			tokens = undefined
			if r.access_token
				tokens =
					access_token : r.access_token
			else if r.oauth_token and r.oauth_token_secret
				tokens =
					oauth_token: r.oauth_token
					oauth_token_secret: r.oauth_token_secret
			headers =
				oauthio:
					k: cache.public_key
			if (tokens.oauth_token and tokens.oauth_token_secret)
				headers.oauthio.oauthv = '1'
			for k of tokens
				headers.oauthio[k] = tokens[k]
			headers.oauthio = qs.stringify headers.oauthio

			url = encodeURIComponent url
			url = "/" + url unless url[0] is "/"
			url = cache.oauthd_url + "/request/" + r.provider + url

			get_options = undefined
			if (method == 'GET')
				get_options = options
				options = undefined

			options = {
				method: method,
				url: url,
				headers: headers,
				form: if options && !options.json then options else null,
				json: if options then options.json else null,
				qs: get_options
			}

			request(options, (error, r, body) ->
				response = undefined
				if body? and r.statusCode >= 200 and r.statusCode < 300
					if typeof body is 'string'
						try
							response = JSON.parse body
						catch
					if typeof body is 'object'
						response = body
					defer.resolve response
					return
				else
					defer.reject {error:error,body:body,status:r.statusCode,message:r.statusMessage};
				if error
					defer.reject error
			);


			return defer.promise
		make_me_request: (r, opts) ->
			defer = Q.defer()

			if r.error?
				defer.reject new Error('Not authenticated for provider \'' + r.provider + '\'')
				return defer.promise

			tokens = undefined
			if r.access_token
				tokens =
					access_token : r.access_token
			else if r.oauth_token and r.oauth_token_secret
				tokens =
					oauth_token: r.oauth_token
					oauth_token_secret: r.oauth_token_secret

			headers =
				oauthio:
					k: cache.public_key
			if (tokens.oauth_token and tokens.oauth_token_secret)
				headers.oauthio.oauthv1 = '1'
			for k of tokens
				headers.oauthio[k] = tokens[k]
			headers.oauthio = qs.stringify headers.oauthio

			body = undefined

			if opts?
				body = {
					filter: opts.join(',')
				}
			url = r.provider + '/me'
			url = cache.oauthd_url + '/auth/' + url


			options = {
				method: "GET",
				url: url,
				headers: headers,
				qs: body
			}
			request(options, (error, r, body) ->
				response = undefined
				if body? and r.statusCode == 200
					if typeof body is 'string'
						response = JSON.parse body
					if typeof body is 'object'
						response = body
					defer.resolve response.data
					return
				else if r.statusCode == 501
					defer.reject new Error(body)
				else
					defer.reject new Error("An error occured while retrieving the user's information")
				if error
					defer.reject error
			);

			return defer.promise
	}
