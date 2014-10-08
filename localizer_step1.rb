require 'unicode'
require 'colorize'
require 'yaml'

$settings = {}

def update_str str, identation, key, value
	str += identation + "#{key}:"
	if [Array, Hash].include? value.class
		str += "\n"
		str += iterate(value, identation + "  ")+"\n"
	else
		if value.class == String
			str += " \"#{value.gsub('"','\"')}\"\n"
		else
			str += " #{value}\n"
		end
	end
	str
end

def iterate hsh, identation
	str = ""
	if hsh.class == Array
		hsh.each_with_index do |value, key|
			str = update_str str, identation, key, value
		end
	elsif hsh.class == Hash
		hsh.each do |key, value|
			str = update_str str, identation, key, value
		end
	end
	str
end

class Hash
	def to_yaml_bsa #колхоз, чтобы получить yaml без нервотрёпки
		iterate self, ""
	end
end

#- Common unicode string helpers --------------------------------------- 
class String

	def words_array
		self.split(/[^a-zA-Zа-яА-ЯёЁ0-9]/).reject(&:empty?)
	end

	def words_str
		self.words_array.join(' ')
	end

	def word_count
		self.words_array.size
	end

	def downcase
		Unicode::downcase(self)
	end

	def downcase!
		self.replace downcase
	end

	def upcase
		Unicode::upcase(self)
	end

	def upcase!
		self.replace upcase
	end

	def capitalize
		Unicode::capitalize(self)
	end

	def capitalize!
		self.replace capitalize
	end

end

#- Разбор Ruby файла -------------------------------------------------------------------------------------------
def phrases_templates
	[
		/(([а-яА-ЯёЁ]+[\!\?\,\.\s–\-:;><\)\(\&a-zA-Z]*)++)/
	]
end

#- Разбор Ruby файла -------------------------------------------------------------------------------------------
def localize(filename, template_numbers)
	file_content = file2str filename
	template_numbers.each do |template_number|
		create_dictionary(filename, file_content, phrases_templates[template_number])
	end
end

#- обновление / создание словаря из встреченных в файле по регулярному выражению -------------------------------
def create_dictionary(filename, file_content, regexp)
	first_n = 4
	last_m = 2
	namespace = filename.split('/')[1].split(/[_\.]/)[0]
	file_strings = file_content.split(/\n/)
	file_strings.each_with_index do |str_original, str_number|
		str = str_original.clone
		if filename =~ /\.rb$/
			str.gsub!(/#[^{].+$/,'') #Вырезаем комментарии
		elsif filename =~ /\.haml$/
			str.gsub!(/^\s*\/.+$/,'') #Вырезаем комментарии
			str.gsub!(/^\s*-\s*#.+$/,'') #Вырезаем комментарии
		end
		if str =~ regexp
			result = str.scan(regexp)
#			puts result.inspect.magenta
#			puts str.yellow
			result.each do |arr|
				phrase = arr[0]
				if phrase.word_count > first_n + last_m
					words_array = phrase.words_array
					phrase = words_array[0..first_n-1].join(' ')+"  "+words_array[-last_m..-1].join(' ')
				else
					phrase = phrase.words_str
				end
				puts "#{filename} - ".yellow + "#{namespace}.#{phrase.downcase.gsub(/[^а-яА-ЯёЁa-zA-Z0-9]/,'_')}".cyan
				$settings[filename] ||= {}
				position = $settings[filename].keys.size+1
				new_episode = {}
				new_episode["номер_строки"] = str_number
				new_episode["ключ_фразы"] = "#{namespace}.#{phrase.downcase.gsub(/[^а-яА-ЯёЁa-zA-Z0-9]/,'_')}"
				new_episode["оригинал_фразы"] = arr[0]
				new_episode["оригинальная_строка_файла"] = str_original
				new_episode["действие"] = "[]"
				$settings[filename]["#{position}"] = new_episode
			end
		end
	end
end

#- Читает файл в строку ----------------------------------------------------------------------------------------
def file2str(filename)
	file_content = ""
	File.open(filename, "r:UTF-8") do |file|
		file_content = file.read
	end
	file_content
end

def settings_message
	"
# Конфигурационный файл подготовки Rails-проекта к интернационализации
# Строки файла устроены следующим образом:
# mailers/preorder_mailer.rb:                                                              # Имя файла с исходным кодом
#  1:                                                                                      # порядковый номер фразы в исходном коде
#    номер_строки: 8                                                                       # Номер строки с найденной фразой
#    ключ_фразы: \"preorder.ошибка_покупки_тура\"                                          # Ключ фразы для yml файла. Можете изменять его
#    оригинал_фразы: \"Ошибка покупки тура\"                                               # Оригинал найденной фразы в исходном коде
#    оригинальная_строка_файла: \"    mail(to: email, subject: 'Ошибка покупки тура')\"    # Строка файла, содержащая фразу целиком, нужна для понимания контекста
#    действие: \"[]\"                                                                      # Вид действия, которое нужно совершить

# Этап 1. Настройка
#  В нижеследующих строках установите в началах строк флаги по следующему принципу:
#  [] - Не изменять текущую фразу
#  [1] - Заменить как обычную строку Ruby, заключённую в одинарные кавычки, целиком вместе с кавычками.
#        Пример замены: 'ваша фраза' => I18n.t(:ваша_фраза)
#  [2] - То же самое, что и [1], только фраза заключена в двойные кавычки.
#        Пример: \"ваша фраза\" => I18n.t(:ваша_фраза)
#  [3] - Заменить фразу на вычисляемое выражение внутри строки
#        Пример: \"Ваша фраза \#\{index\} Другая фраза\" => \"\#\{I18n.t(\"ваша_фраза\"\} \#\{index\} \#\{I18n.t(\"другая_фраза\")\}\"
	"
end

#-----------------------------------------------------------------------
Dir.glob("**/*").each do |entryname|
	if File.directory? entryname
		next
	elsif entryname =~ /localizer.+?\.rb$/
		next
	elsif entryname.split('/')[0..1].include? "admin"
		next
	end
	if entryname =~ /\.rb$/i
		localize entryname, [0]
	elsif entryname =~ /\.haml$/i
		localize entryname, [0]
	end
end
File.open("settings.yml", "w") do |settings_file|
	settings_file.write "#{settings_message}\n\n"
	settings_file.write $settings.to_yaml_bsa
end

#puts $settings.inspect